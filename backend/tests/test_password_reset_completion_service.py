from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.core.security import (
    hash_opaque_token,
    hash_password,
    verify_password,
)
from kalonet_backend.models import PasswordResetToken, RefreshSession, User
from kalonet_backend.repositories import (
    PasswordResetTokenRepository,
    RefreshSessionRepository,
    UserRepository,
)
from kalonet_backend.services import (
    InvalidOrExpiredResetTokenError,
    PasswordResetCompletionService,
)


def create_reset_fixture(db_session: Session) -> tuple[User, str, datetime]:
    user = UserRepository(db_session).create(
        email=f"reset-completion-{uuid4()}@example.com",
        password_hash=hash_password("old correct horse battery staple"),
    )
    plain_token = f"reset-token-{uuid4()}"
    now = datetime.now(UTC)
    PasswordResetTokenRepository(db_session).create(
        user_id=user.id,
        token_hash=hash_opaque_token(plain_token),
        expires_at=now + timedelta(minutes=30),
    )
    RefreshSessionRepository(db_session).create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="a" * 64,
        family_id=uuid4(),
        expires_at=now + timedelta(days=30),
    )
    return user, plain_token, now


def test_completion_changes_password_consumes_token_and_revokes_sessions(
    db_session: Session,
) -> None:
    user, plain_token, now = create_reset_fixture(db_session)
    service = PasswordResetCompletionService(db_session, clock=lambda: now)

    service.complete(
        reset_token=plain_token,
        new_password="new correct horse battery staple",
    )

    db_session.refresh(user)
    stored_token = db_session.scalar(
        select(PasswordResetToken).where(PasswordResetToken.user_id == user.id)
    )
    stored_session = db_session.scalar(
        select(RefreshSession).where(RefreshSession.user_id == user.id)
    )

    assert stored_token is not None
    assert stored_token.consumed_at == now
    assert stored_session is not None
    assert stored_session.revoked_at == now
    assert stored_session.revocation_reason == "password_reset"
    assert stored_session.rotated_at is None
    assert not verify_password("old correct horse battery staple", user.password_hash)
    assert verify_password("new correct horse battery staple", user.password_hash)


def test_completion_rejects_replay_without_changing_state(
    db_session: Session,
) -> None:
    _, plain_token, now = create_reset_fixture(db_session)
    service = PasswordResetCompletionService(db_session, clock=lambda: now)

    service.complete(
        reset_token=plain_token,
        new_password="new correct horse battery staple",
    )

    with pytest.raises(InvalidOrExpiredResetTokenError):
        service.complete(
            reset_token=plain_token,
            new_password="another correct horse battery staple",
        )


def test_completion_rejects_expired_token(
    db_session: Session,
) -> None:
    user = UserRepository(db_session).create(
        email=f"expired-reset-{uuid4()}@example.com",
        password_hash=hash_password("old correct horse battery staple"),
    )
    plain_token = f"expired-token-{uuid4()}"
    created_at = datetime.now(UTC)
    PasswordResetTokenRepository(db_session).create(
        user_id=user.id,
        token_hash=hash_opaque_token(plain_token),
        expires_at=created_at + timedelta(minutes=30),
    )
    service = PasswordResetCompletionService(
        db_session,
        clock=lambda: created_at + timedelta(minutes=31),
    )

    with pytest.raises(InvalidOrExpiredResetTokenError):
        service.complete(
            reset_token=plain_token,
            new_password="new correct horse battery staple",
        )
