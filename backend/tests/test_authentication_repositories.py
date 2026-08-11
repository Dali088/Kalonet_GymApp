from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy.orm import Session

from kalonet_backend.repositories import (
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
    assert refresh_session.expires_at == expires_at
    assert refresh_session.revoked_at is None
