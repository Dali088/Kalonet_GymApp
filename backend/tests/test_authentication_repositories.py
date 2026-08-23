from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy.orm import Session

from kalonet_backend.repositories import (
    PasswordResetTokenRepository,
    RefreshSessionRepository,
    UserRepository,
)


def test_user_repository_creates_user(
    db_session: Session,
) -> None:
    repository = UserRepository(db_session)

    user = repository.create(
        email="repository-user@example.com",
        password_hash="example-password-hash",
    )

    assert user.id is not None
    assert user.email == "repository-user@example.com"
    assert user.password_hash == "example-password-hash"


def test_user_repository_finds_user_by_email(
    db_session: Session,
) -> None:
    repository = UserRepository(db_session)

    created_user = repository.create(
        email="lookup@example.com",
        password_hash="example-password-hash",
    )

    found_user = repository.get_by_email("lookup@example.com")

    assert found_user is not None
    assert found_user.id == created_user.id
    assert found_user.email == "lookup@example.com"


def test_user_repository_returns_none_for_unknown_email(
    db_session: Session,
) -> None:
    repository = UserRepository(db_session)

    found_user = repository.get_by_email("missing@example.com")

    assert found_user is None


def test_user_repository_finds_user_by_id(
    db_session: Session,
) -> None:
    repository = UserRepository(db_session)

    created_user = repository.create(
        email="id-lookup@example.com",
        password_hash="example-password-hash",
    )

    found_user = repository.get_by_id(created_user.id)

    assert found_user is not None
    assert found_user.id == created_user.id


def test_refresh_session_repository_creates_session(
    db_session: Session,
) -> None:
    user_repository = UserRepository(db_session)
    session_repository = RefreshSessionRepository(db_session)

    user = user_repository.create(
        email="session-user@example.com",
        password_hash="example-password-hash",
    )

    family_id = uuid4()
    session_id = uuid4()
    expires_at = datetime.now(UTC) + timedelta(days=30)

    refresh_session = session_repository.create(
        session_id=session_id,
        user_id=user.id,
        token_hash="a" * 64,
        family_id=family_id,
        expires_at=expires_at,
    )

    assert refresh_session.id == session_id
    assert refresh_session.user_id == user.id
    assert refresh_session.token_hash == "a" * 64
    assert refresh_session.family_id == family_id
    assert refresh_session.parent_session_id is None
    assert refresh_session.expires_at == expires_at
    assert refresh_session.revoked_at is None


def test_refresh_session_repository_creates_rotation_lineage(
    db_session: Session,
) -> None:
    user_repository = UserRepository(db_session)
    session_repository = RefreshSessionRepository(db_session)

    user = user_repository.create(
        email="lineage-user@example.com",
        password_hash="example-password-hash",
    )

    family_id = uuid4()
    expires_at = datetime.now(UTC) + timedelta(days=30)
    parent_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="b" * 64,
        family_id=family_id,
        expires_at=expires_at,
    )

    child_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="c" * 64,
        family_id=family_id,
        expires_at=expires_at,
        parent_session_id=parent_session.id,
    )

    assert child_session.parent_session_id == parent_session.id


def test_refresh_session_repository_locks_by_token_hash(
    db_session: Session,
) -> None:
    user_repository = UserRepository(db_session)
    session_repository = RefreshSessionRepository(db_session)

    user = user_repository.create(
        email="locked-session@example.com",
        password_hash="example-password-hash",
    )
    refresh_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="c" * 64,
        family_id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(days=30),
    )

    locked_session = session_repository.get_by_token_hash_for_update("c" * 64)

    assert locked_session is not None
    assert locked_session.id == refresh_session.id


def test_refresh_session_repository_finds_by_token_hash_without_lock(
    db_session: Session,
) -> None:
    user_repository = UserRepository(db_session)
    session_repository = RefreshSessionRepository(db_session)

    user = user_repository.create(
        email="unlocked-session@example.com",
        password_hash="example-password-hash",
    )
    refresh_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="f" * 64,
        family_id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(days=30),
    )

    found_session = session_repository.get_by_token_hash("f" * 64)

    assert found_session is not None
    assert found_session.id == refresh_session.id


def test_refresh_session_repository_revokes_only_active_family_sessions(
    db_session: Session,
) -> None:
    user_repository = UserRepository(db_session)
    session_repository = RefreshSessionRepository(db_session)

    user = user_repository.create(
        email="family-revocation@example.com",
        password_hash="example-password-hash",
    )
    family_id = uuid4()
    expires_at = datetime.now(UTC) + timedelta(days=30)

    active_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="d" * 64,
        family_id=family_id,
        expires_at=expires_at,
    )
    rotated_session = session_repository.create(
        session_id=uuid4(),
        user_id=user.id,
        token_hash="e" * 64,
        family_id=family_id,
        expires_at=expires_at,
    )
    rotated_session.rotated_at = rotated_session.created_at + timedelta(seconds=1)
    db_session.flush()

    revoked_at = max(active_session.created_at, rotated_session.created_at) + timedelta(seconds=1)
    revoked_count = session_repository.revoke_active_family(
        family_id=family_id,
        revoked_at=revoked_at,
        revocation_reason="token_reuse",
    )

    assert revoked_count == 1
    assert active_session.revoked_at is not None
    assert active_session.revocation_reason == "token_reuse"
    assert rotated_session.revoked_at is None
    assert rotated_session.revocation_reason is None


def test_password_reset_repository_invalidates_only_active_tokens(
    db_session: Session,
) -> None:
    user = UserRepository(db_session).create(
        email="reset-repository@example.com",
        password_hash="example-password-hash",
    )
    repository = PasswordResetTokenRepository(db_session)
    created_time = datetime.now(UTC)
    comparison_time = created_time + timedelta(minutes=45)

    active_token = repository.create(
        user_id=user.id,
        token_hash="1" * 64,
        expires_at=created_time + timedelta(hours=1),
    )
    expired_token = repository.create(
        user_id=user.id,
        token_hash="2" * 64,
        expires_at=created_time + timedelta(minutes=30),
    )
    consumed_token = repository.create(
        user_id=user.id,
        token_hash="3" * 64,
        expires_at=created_time + timedelta(hours=1),
    )
    consumed_token.consumed_at = created_time
    db_session.flush()

    invalidated_count = repository.invalidate_active_for_user(
        user_id=user.id,
        invalidated_at=comparison_time,
        now=comparison_time,
    )

    assert invalidated_count == 1
    assert active_token.invalidated_at == comparison_time
    assert expired_token.invalidated_at is None
    assert consumed_token.invalidated_at is None
