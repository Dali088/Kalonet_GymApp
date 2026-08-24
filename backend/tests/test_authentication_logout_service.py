from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.core.config import Settings
from kalonet_backend.models import RefreshSession
from kalonet_backend.repositories import RefreshSessionRepository, UserRepository
from kalonet_backend.services import (
    AuthenticationTokenService,
    LogoutService,
    SessionMismatchError,
)

TEST_SECRET = "test-jwt-secret-key-containing-at-least-32-bytes"


def create_token_service() -> AuthenticationTokenService:
    return AuthenticationTokenService(
        Settings(
            environment="test",
            jwt_secret_key=TEST_SECRET,
            access_token_lifetime_seconds=900,
            refresh_token_lifetime_days=30,
        )
    )


def create_logout_fixture(
    db_session: Session,
) -> tuple[AuthenticationTokenService, object, object, object]:
    token_service = create_token_service()
    user = UserRepository(db_session).create(
        email=f"logout-service-{uuid4()}@example.com",
        password_hash="example-password-hash",
    )
    session_id = uuid4()
    issued_tokens = token_service.issue_session_tokens(
        user_id=user.id,
        session_id=session_id,
        now=datetime.now(UTC),
    )
    refresh_session = RefreshSessionRepository(db_session).create(
        session_id=session_id,
        user_id=user.id,
        token_hash=issued_tokens.refresh_token_hash,
        family_id=uuid4(),
        expires_at=issued_tokens.refresh_token_expires_at,
    )
    # Commit fixture setup inside the test's outer transaction so a service
    # rollback cannot erase the rows this test is checking.
    db_session.commit()

    return token_service, user, refresh_session, issued_tokens


def test_logout_revokes_the_matching_session(
    db_session: Session,
) -> None:
    _, user, refresh_session, issued_tokens = create_logout_fixture(db_session)
    logout_service = LogoutService(
        db_session,
        clock=lambda: refresh_session.created_at + timedelta(seconds=1),
    )

    logout_service.logout(
        user_id=user.id,
        session_id=refresh_session.id,
        refresh_token=issued_tokens.refresh_token,
    )

    assert refresh_session.revoked_at == refresh_session.created_at + timedelta(seconds=1)
    assert refresh_session.revocation_reason == "logout"


def test_logout_is_repeatable_for_an_already_revoked_session(
    db_session: Session,
) -> None:
    _, user, refresh_session, issued_tokens = create_logout_fixture(db_session)
    logout_service = LogoutService(
        db_session,
        clock=lambda: refresh_session.created_at + timedelta(seconds=1),
    )

    logout_service.logout(
        user_id=user.id,
        session_id=refresh_session.id,
        refresh_token=issued_tokens.refresh_token,
    )
    logout_service.logout(
        user_id=user.id,
        session_id=refresh_session.id,
        refresh_token=issued_tokens.refresh_token,
    )

    assert refresh_session.revocation_reason == "logout"


def test_logout_rejects_a_different_user_or_session(
    db_session: Session,
) -> None:
    _, first_user, first_session, first_tokens = create_logout_fixture(db_session)
    _, second_user, second_session, second_tokens = create_logout_fixture(db_session)
    logout_service = LogoutService(db_session)

    with pytest.raises(SessionMismatchError):
        logout_service.logout(
            user_id=first_user.id,
            session_id=first_session.id,
            refresh_token=second_tokens.refresh_token,
        )

    with pytest.raises(SessionMismatchError):
        logout_service.logout(
            user_id=first_user.id,
            session_id=second_session.id,
            refresh_token=first_tokens.refresh_token,
        )

    stored_sessions = list(
        db_session.scalars(
            select(RefreshSession).where(
                RefreshSession.id.in_((first_session.id, second_session.id))
            )
        )
    )
    assert len(stored_sessions) == 2
    assert all(refresh_session.revoked_at is None for refresh_session in stored_sessions)
