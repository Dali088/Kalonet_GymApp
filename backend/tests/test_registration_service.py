import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from kalonet_backend.core.config import Settings
from kalonet_backend.core.security import (
    decode_access_token,
    hash_opaque_token,
    verify_password,
)
from kalonet_backend.models import RefreshSession, User
from kalonet_backend.repositories import UserRepository
from kalonet_backend.services import (
    AuthenticationTokenService,
    EmailAlreadyRegisteredError,
    RegistrationService,
)

TEST_SECRET = "test-jwt-secret-key-containing-at-least-32-bytes"

VALID_PASSWORD = "correct horse battery staple"


def create_registration_service(
    db_session: Session,
) -> RegistrationService:
    settings = Settings(
        environment="test",
        jwt_secret_key=TEST_SECRET,
        access_token_lifetime_seconds=900,
        refresh_token_lifetime_days=30,
    )

    return RegistrationService(
        db_session,
        AuthenticationTokenService(settings),
    )


def test_registration_creates_user_and_session(
    db_session: Session,
) -> None:
    service = create_registration_service(db_session)

    result = service.register(
        email="karim@example.com",
        password=VALID_PASSWORD,
    )

    user = UserRepository(db_session).get_by_email("karim@example.com")

    assert user is not None

    assert result.user_id == user.id
    assert result.email == "karim@example.com"
    assert result.onboarding_completed is False

    assert user.password_hash != VALID_PASSWORD
    assert verify_password(
        VALID_PASSWORD,
        user.password_hash,
    )

    refresh_session = db_session.scalar(
        select(RefreshSession).where(RefreshSession.user_id == user.id)
    )

    assert refresh_session is not None

    assert refresh_session.token_hash == hash_opaque_token(result.refresh_token)

    claims = decode_access_token(
        result.access_token,
        secret_key=TEST_SECRET,
    )

    assert claims.user_id == user.id
    assert claims.session_id == refresh_session.id

    assert result.access_token_expires_in_seconds == 900


def test_registration_rejects_existing_email(
    db_session: Session,
) -> None:
    service = create_registration_service(db_session)

    service.register(
        email="duplicate@example.com",
        password=VALID_PASSWORD,
    )

    with pytest.raises(EmailAlreadyRegisteredError):
        service.register(
            email="duplicate@example.com",
            password=VALID_PASSWORD,
        )

    user_count = db_session.scalar(
        select(func.count()).select_from(User).where(User.email == "duplicate@example.com")
    )

    session_count = db_session.scalar(
        select(func.count())
        .select_from(RefreshSession)
        .join(User, RefreshSession.user_id == User.id)
        .where(User.email == "duplicate@example.com")
    )

    assert user_count == 1
    assert session_count == 1


def test_registration_rolls_back_if_session_creation_fails(
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fail_session_creation(
        *args: object,
        **kwargs: object,
    ) -> None:
        raise RuntimeError("Simulated refresh-session failure.")

    monkeypatch.setattr(
        "kalonet_backend.services.authentication.RefreshSessionRepository.create",
        fail_session_creation,
    )

    service = create_registration_service(db_session)

    with pytest.raises(
        RuntimeError,
        match="Simulated refresh-session failure",
    ):
        service.register(
            email="rollback@example.com",
            password=VALID_PASSWORD,
        )

    user = UserRepository(db_session).get_by_email("rollback@example.com")

    assert user is None
