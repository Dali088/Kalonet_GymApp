from datetime import UTC, datetime, timedelta
from threading import Barrier, BrokenBarrierError, Thread
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from kalonet_backend.core.config import Settings
from kalonet_backend.core.security import hash_opaque_token
from kalonet_backend.models import RefreshSession, User
from kalonet_backend.repositories import RefreshSessionRepository, UserRepository
from kalonet_backend.services import (
    AuthenticationTokenService,
    InvalidRefreshTokenError,
    RefreshTokenReuseDetectedError,
    RefreshTokenService,
)

TEST_SECRET = "test-jwt-secret-key-containing-at-least-32-bytes"


def create_token_service() -> AuthenticationTokenService:
    settings = Settings(
        environment="test",
        jwt_secret_key=TEST_SECRET,
        access_token_lifetime_seconds=900,
        refresh_token_lifetime_days=30,
    )

    return AuthenticationTokenService(settings)


def create_refresh_session(
    db_session: Session,
    *,
    created_at: datetime | None = None,
    revoked: bool = False,
) -> tuple[str, RefreshSession]:
    issued_at = created_at or datetime.now(UTC)
    token_service = create_token_service()
    user = UserRepository(db_session).create(
        email=f"refresh-{uuid4()}@example.com",
        password_hash="example-password-hash",
    )
    session_id = uuid4()
    issued_tokens = token_service.issue_session_tokens(
        user_id=user.id,
        session_id=session_id,
        now=issued_at,
    )
    refresh_session = RefreshSessionRepository(db_session).create(
        session_id=session_id,
        user_id=user.id,
        token_hash=issued_tokens.refresh_token_hash,
        family_id=uuid4(),
        expires_at=issued_tokens.refresh_token_expires_at,
    )

    if revoked:
        refresh_session.revoked_at = refresh_session.created_at + timedelta(seconds=1)
        refresh_session.revocation_reason = "logout"
        db_session.flush()

    return issued_tokens.refresh_token, refresh_session


def create_refresh_service(
    db_session: Session,
    *,
    now: datetime,
) -> RefreshTokenService:
    return RefreshTokenService(
        db_session,
        create_token_service(),
        clock=lambda: now,
    )


def test_refresh_rotates_session_and_preserves_lineage(
    db_session: Session,
) -> None:
    refresh_token, original_session = create_refresh_session(db_session)
    rotation_time = original_session.created_at + timedelta(seconds=1)
    service = create_refresh_service(db_session, now=rotation_time)

    result = service.rotate(refresh_token=refresh_token)

    replacement_session = db_session.scalar(
        select(RefreshSession).where(
            RefreshSession.token_hash == hash_opaque_token(result.refresh_token),
        )
    )

    assert replacement_session is not None
    assert original_session.rotated_at == rotation_time
    assert replacement_session.parent_session_id == original_session.id
    assert replacement_session.family_id == original_session.family_id
    assert replacement_session.revoked_at is None


def test_refresh_rejects_unknown_and_expired_tokens(
    db_session: Session,
) -> None:
    service = create_refresh_service(db_session, now=datetime.now(UTC))

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate(refresh_token="")

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate(refresh_token="unknown-token")

    expired_token, expired_session = create_refresh_session(db_session)
    expired_session.expires_at = expired_session.created_at + timedelta(seconds=1)
    db_session.flush()
    expired_now = expired_session.expires_at + timedelta(seconds=1)
    service = create_refresh_service(db_session, now=expired_now)

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate(refresh_token=expired_token)


def test_refresh_rejects_revoked_tokens(
    db_session: Session,
) -> None:
    revoked_token, revoked_session = create_refresh_session(db_session, revoked=True)
    service = create_refresh_service(
        db_session,
        now=revoked_session.revoked_at + timedelta(seconds=1),
    )

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate(refresh_token=revoked_token)


def test_refresh_reuse_revokes_active_token_family(
    db_session: Session,
) -> None:
    refresh_token, original_session = create_refresh_session(db_session)
    rotation_time = original_session.created_at + timedelta(seconds=1)
    service = create_refresh_service(db_session, now=rotation_time)

    first_result = service.rotate(refresh_token=refresh_token)

    with pytest.raises(RefreshTokenReuseDetectedError):
        service.rotate(refresh_token=refresh_token)

    replacement_session = db_session.scalar(
        select(RefreshSession).where(
            RefreshSession.token_hash == hash_opaque_token(first_result.refresh_token),
        )
    )

    assert replacement_session is not None
    assert original_session.rotated_at == rotation_time
    assert replacement_session.revoked_at == rotation_time
    assert replacement_session.revocation_reason == "token_reuse"


def test_concurrent_refresh_attempts_allow_only_one_rotation(
    database_engine,
) -> None:
    """Prove PostgreSQL row locking prevents double rotation."""

    session_factory = sessionmaker(
        bind=database_engine,
        autoflush=False,
        expire_on_commit=False,
    )
    setup_session = session_factory()
    refresh_token, original_session = create_refresh_session(setup_session)
    setup_session.commit()
    setup_session.close()

    start_barrier = Barrier(2)
    results: list[str] = []
    errors: list[BaseException] = []

    def attempt_refresh() -> None:
        session = session_factory()

        try:
            start_barrier.wait(timeout=10)
            service = create_refresh_service(
                session,
                now=original_session.created_at + timedelta(seconds=1),
            )
            service.rotate(refresh_token=refresh_token)
            results.append("success")
        except RefreshTokenReuseDetectedError:
            results.append("reuse")
        except InvalidRefreshTokenError:
            results.append("invalid")
        except BrokenBarrierError as error:
            errors.append(error)
        except BaseException as error:
            errors.append(error)
        finally:
            session.close()

    threads = [Thread(target=attempt_refresh) for _ in range(2)]

    for thread in threads:
        thread.start()

    for thread in threads:
        thread.join(timeout=15)

    assert not errors
    assert all(not thread.is_alive() for thread in threads)
    assert results.count("success") == 1
    assert results.count("reuse") + results.count("invalid") == 1

    verification_session = session_factory()
    try:
        stored_original = verification_session.get(RefreshSession, original_session.id)
        replacement_sessions = list(
            verification_session.scalars(
                select(RefreshSession).where(
                    RefreshSession.parent_session_id == original_session.id,
                )
            )
        )

        assert stored_original is not None
        assert stored_original.rotated_at is not None
        assert len(replacement_sessions) == 1
    finally:
        user = verification_session.get(User, original_session.user_id)
        assert user is not None
        verification_session.delete(user)
        verification_session.commit()
        verification_session.close()
