from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from kalonet_backend.schemas.authentication import (
    RegistrationRequest,
    SessionCreateRequest,
    SessionResponse,
    SessionUserResponse,
)

VALID_PASSWORD = "correct horse battery staple"


def test_registration_normalizes_email() -> None:
    request = RegistrationRequest(
        email="  Karim@Example.COM  ",
        password=VALID_PASSWORD,
    )

    assert str(request.email) == "karim@example.com"


def test_registration_does_not_modify_password() -> None:
    password = "  correct horse battery staple  "

    request = RegistrationRequest(
        email="karim@example.com",
        password=password,
    )

    assert request.password == password


def test_registration_rejects_short_password() -> None:
    with pytest.raises(ValidationError):
        RegistrationRequest(
            email="karim@example.com",
            password="too-short",
        )


def test_registration_rejects_blocklisted_password() -> None:
    with pytest.raises(ValidationError) as error:
        RegistrationRequest(
            email="karim@example.com",
            password="Password1234567",
        )

    assert "too common" in str(error.value)


def test_registration_rejects_invalid_email() -> None:
    with pytest.raises(ValidationError):
        RegistrationRequest(
            email="not-an-email",
            password=VALID_PASSWORD,
        )


def test_registration_rejects_unexpected_fields() -> None:
    with pytest.raises(ValidationError):
        RegistrationRequest(
            email="karim@example.com",
            password=VALID_PASSWORD,
            administrator=True,
        )


def test_login_normalizes_email() -> None:
    request = SessionCreateRequest(
        email="  Karim@Example.COM  ",
        password="submitted-password",
    )

    assert request.email == "karim@example.com"


def test_login_does_not_apply_new_password_policy() -> None:
    request = SessionCreateRequest(
        email="karim@example.com",
        password="x",
    )

    assert request.password == "x"


def test_session_response_matches_contract_shape() -> None:
    response = SessionResponse(
        access_token="access-token",
        refresh_token="refresh-token",
        access_token_expires_in_seconds=900,
        refresh_token_expires_at=datetime(
            2026,
            8,
            31,
            15,
            42,
            19,
            tzinfo=UTC,
        ),
        user=SessionUserResponse(
            id="9d829c62-3e75-4cf7-a25e-2e0e19777bc1",
            email="karim@example.com",
            onboarding_completed=False,
        ),
    )

    payload = response.model_dump(mode="json")

    assert set(payload) == {
        "access_token",
        "refresh_token",
        "token_type",
        "access_token_expires_in_seconds",
        "refresh_token_expires_at",
        "user",
    }
    assert payload["token_type"] == "bearer"
    assert payload["access_token_expires_in_seconds"] == 900
    assert payload["user"]["onboarding_completed"] is False
