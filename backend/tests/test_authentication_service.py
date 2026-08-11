import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from kalonet_backend.core.config import Settings
from kalonet_backend.core.security import hash_opaque_token
from kalonet_backend.models import RefreshSession, User
from kalonet_backend.services import (
    AuthenticationTokenService,
    InvalidCredentialsError,
    LoginService,
    RegistrationService,
)

TEST_SECRET = "test-jwt-secret-key-containing-at-least-32-bytes"
VALID_PASSWORD = "correct horse battery staple"


def create_services(
    db_session: Session,
) -> tuple[RegistrationService, LoginService]:
    settings = Settings(
        environment="test",
        jwt_secret_key=TEST_SECRET,
        access_token_lifetime_seconds=900,
        refresh_token_lifetime_days=30,
    )
    token_service = AuthenticationTokenService(settings)

    return (
        RegistrationService(db_session, token_service),
        LoginService(db_session, token_service),
    )


def test_login_creates_a_new_authenticated_session(
    db_session: Session,
) -> None:
    registration_service, login_service = create_services(db_session)

    registration_service.register(
        email="login@example.com",
        password=VALID_PASSWORD,
    )

    result = login_service.login(
        email="login@example.com",
        password=VALID_PASSWORD,
    )

    user = db_session.scalar(select(User).where(User.email == "login@example.com"))

    assert user is not None

    session_count = db_session.scalar(
        select(func.count()).select_from(RefreshSession).where(RefreshSession.user_id == user.id)
    )
    login_session = db_session.scalar(
        select(RefreshSession).where(
            RefreshSession.token_hash == hash_opaque_token(result.refresh_token)
        )
    )

    assert result.user_id == user.id
    assert result.email == user.email
    assert result.onboarding_completed is False
    assert session_count == 2
    assert login_session is not None
    assert login_session.user_id == user.id


@pytest.mark.parametrize(
    ("email", "password"),
    [
        ("login@example.com", "wrong password"),
        ("missing@example.com", VALID_PASSWORD),
    ],
)
def test_login_rejects_invalid_credentials_without_creating_a_session(
    db_session: Session,
    email: str,
    password: str,
) -> None:
    registration_service, login_service = create_services(db_session)

    registration_service.register(
        email="login@example.com",
        password=VALID_PASSWORD,
    )

    with pytest.raises(InvalidCredentialsError):
        login_service.login(
            email=email,
            password=password,
        )

    session_count = db_session.scalar(select(func.count()).select_from(RefreshSession))

    assert session_count == 1
