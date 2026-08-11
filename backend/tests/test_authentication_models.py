from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from kalonet_backend.models import (
    PasswordResetToken,
    RefreshSession,
    User,
    UserProfile,
    UserSettings,
)


def create_user(
    session: Session,
    email: str = "test@example.com",
) -> User:
    """Create and flush one valid test user."""

    user = User(
        email=email,
        password_hash="not-a-real-password-hash",
    )

    session.add(user)
    session.flush()

    return user


def test_user_settings_receive_defaults(
    db_session: Session,
) -> None:
    user = create_user(db_session)

    settings = UserSettings(user_id=user.id)

    db_session.add(settings)
    db_session.flush()
    db_session.refresh(settings)

    assert settings.measurement_system == "metric"
    assert settings.time_zone == "UTC"
    assert settings.theme_preference == "system"


def test_database_rejects_non_normalized_email(
    db_session: Session,
) -> None:
    user = User(
        email="User@Example.com",
        password_hash="not-a-real-password-hash",
    )

    db_session.add(user)

    with pytest.raises(IntegrityError):
        db_session.flush()

    db_session.rollback()


def test_database_rejects_expired_refresh_session(
    db_session: Session,
) -> None:
    user = create_user(db_session)

    session = RefreshSession(
        user_id=user.id,
        token_hash="refresh-token-hash",
        family_id=uuid4(),
        expires_at=datetime.now(UTC) - timedelta(minutes=1),
    )

    db_session.add(session)

    with pytest.raises(IntegrityError):
        db_session.flush()

    db_session.rollback()


def test_database_rejects_revoked_refresh_session_without_reason(
    db_session: Session,
) -> None:
    user = create_user(db_session)

    session = RefreshSession(
        user_id=user.id,
        token_hash="a" * 64,
        family_id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(days=30),
        revoked_at=datetime.now(UTC),
    )

    db_session.add(session)

    with pytest.raises(IntegrityError):
        db_session.flush()

    db_session.rollback()


def test_database_rejects_revocation_reason_without_revoked_timestamp(
    db_session: Session,
) -> None:
    user = create_user(db_session)

    session = RefreshSession(
        user_id=user.id,
        token_hash="b" * 64,
        family_id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(days=30),
        revocation_reason="logout",
    )

    db_session.add(session)

    with pytest.raises(IntegrityError):
        db_session.flush()

    db_session.rollback()


def test_deleting_user_cascades_authentication_records(
    db_session: Session,
) -> None:
    user = create_user(db_session)
    user_id = user.id

    profile = UserProfile(user_id=user_id)
    settings = UserSettings(user_id=user_id)

    refresh_session = RefreshSession(
        user_id=user_id,
        token_hash="c" * 64,
        family_id=uuid4(),
        expires_at=datetime.now(UTC) + timedelta(days=30),
    )

    reset_token = PasswordResetToken(
        user_id=user_id,
        token_hash="d" * 64,
        expires_at=datetime.now(UTC) + timedelta(minutes=30),
    )

    db_session.add_all(
        [
            profile,
            settings,
            refresh_session,
            reset_token,
        ]
    )
    db_session.flush()

    db_session.delete(user)
    db_session.flush()

    refresh_count = db_session.scalar(
        select(func.count()).select_from(RefreshSession).where(RefreshSession.user_id == user_id)
    )

    reset_count = db_session.scalar(
        select(func.count())
        .select_from(PasswordResetToken)
        .where(PasswordResetToken.user_id == user_id)
    )

    profile_count = db_session.scalar(
        select(func.count()).select_from(UserProfile).where(UserProfile.user_id == user_id)
    )

    settings_count = db_session.scalar(
        select(func.count()).select_from(UserSettings).where(UserSettings.user_id == user_id)
    )

    assert refresh_count == 0
    assert reset_count == 0
    assert profile_count == 0
    assert settings_count == 0
