from datetime import UTC, datetime, timedelta
from uuid import uuid4

from kalonet_backend.core.security import hash_opaque_token, hash_password
from kalonet_backend.repositories import PasswordResetTokenRepository, UserRepository


def test_login_returns_200_and_session(
    client,
) -> None:
    client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "login-api@example.com",
            "password": "correct horse battery staple",
        },
    )

    response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "LOGIN-API@EXAMPLE.COM",
            "password": "correct horse battery staple",
        },
    )

    assert response.status_code == 200

    payload = response.json()

    assert payload["token_type"] == "bearer"
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["access_token_expires_in_seconds"] == 900
    assert payload["user"]["email"] == "login-api@example.com"
    assert payload["user"]["onboarding_completed"] is False


def test_login_uses_the_same_401_contract_for_unknown_email_and_wrong_password(
    client,
) -> None:
    client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "known-login-api@example.com",
            "password": "correct horse battery staple",
        },
    )

    wrong_password_response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "known-login-api@example.com",
            "password": "wrong password",
        },
    )
    unknown_email_response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "unknown-login-api@example.com",
            "password": "correct horse battery staple",
        },
    )

    assert wrong_password_response.status_code == 401
    assert unknown_email_response.status_code == 401

    wrong_password_error = wrong_password_response.json()["error"]
    unknown_email_error = unknown_email_response.json()["error"]

    assert wrong_password_error["code"] == "invalid_credentials"
    assert unknown_email_error["code"] == "invalid_credentials"
    assert wrong_password_error["message"] == unknown_email_error["message"]
    assert wrong_password_error["details"] == unknown_email_error["details"] == []
    assert wrong_password_error["request_id"]
    assert unknown_email_error["request_id"]


def test_login_limits_requests_per_client_ip(
    client,
) -> None:
    for index in range(10):
        response = client.post(
            "/api/v1/auth/sessions",
            json={
                "email": f"unknown-login-{index}@example.com",
                "password": "wrong password",
            },
        )

        assert response.status_code == 401

    response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "unknown-login-final@example.com",
            "password": "wrong password",
        },
    )

    assert response.status_code == 429

    payload = response.json()

    assert payload["error"]["code"] == "rate_limit_exceeded"
    assert payload["error"]["details"] == []
    assert payload["error"]["request_id"]
    assert response.headers["Retry-After"]


def test_login_limits_failed_attempts_per_email(
    client,
) -> None:
    client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "failed-limit@example.com",
            "password": "correct horse battery staple",
        },
    )

    for _ in range(5):
        response = client.post(
            "/api/v1/auth/sessions",
            json={
                "email": "FAILED-LIMIT@EXAMPLE.COM",
                "password": "wrong password",
            },
        )

        assert response.status_code == 401

    response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "failed-limit@example.com",
            "password": "wrong password",
        },
    )

    assert response.status_code == 429

    payload = response.json()

    assert payload["error"]["code"] == "rate_limit_exceeded"
    assert payload["error"]["details"] == []
    assert payload["error"]["request_id"]
    assert response.headers["Retry-After"]


def test_successful_login_does_not_consume_failed_email_budget(
    client,
) -> None:
    client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "successful-login-limit@example.com",
            "password": "correct horse battery staple",
        },
    )

    for _ in range(4):
        response = client.post(
            "/api/v1/auth/sessions",
            json={
                "email": "successful-login-limit@example.com",
                "password": "wrong password",
            },
        )

        assert response.status_code == 401

    successful_response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "successful-login-limit@example.com",
            "password": "correct horse battery staple",
        },
    )
    fifth_failure_response = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "successful-login-limit@example.com",
            "password": "wrong password",
        },
    )

    assert successful_response.status_code == 200
    assert fifth_failure_response.status_code == 401


def test_refresh_returns_200_and_rotates_the_refresh_token(
    client,
) -> None:
    registration_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "refresh-api@example.com",
            "password": "correct horse battery staple",
        },
    )
    original_refresh_token = registration_response.json()["refresh_token"]

    response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": original_refresh_token},
    )

    assert response.status_code == 200

    payload = response.json()

    assert payload["token_type"] == "bearer"
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["refresh_token"] != original_refresh_token
    assert payload["access_token_expires_in_seconds"] == 900
    assert payload["user"]["email"] == "refresh-api@example.com"


def test_refresh_maps_invalid_tokens_to_the_standard_401_contract(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": ""},
    )

    assert response.status_code == 401

    error = response.json()["error"]

    assert error["code"] == "invalid_refresh_token"
    assert error["details"] == []
    assert error["request_id"]


def test_refresh_maps_reuse_to_401_and_makes_the_replacement_unusable(
    client,
) -> None:
    registration_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "refresh-reuse-api@example.com",
            "password": "correct horse battery staple",
        },
    )
    original_refresh_token = registration_response.json()["refresh_token"]

    rotation_response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": original_refresh_token},
    )
    replacement_refresh_token = rotation_response.json()["refresh_token"]

    reuse_response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": original_refresh_token},
    )

    assert reuse_response.status_code == 401
    assert reuse_response.json()["error"]["code"] == "refresh_token_reuse_detected"

    replacement_response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": replacement_refresh_token},
    )

    assert replacement_response.status_code == 401
    assert replacement_response.json()["error"]["code"] == "invalid_refresh_token"


def test_refresh_limits_attempts_per_token_family(
    client,
) -> None:
    first_registration_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "refresh-limit-first@example.com",
            "password": "correct horse battery staple",
        },
    )
    first_refresh_token = first_registration_response.json()["refresh_token"]

    second_registration_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "refresh-limit-second@example.com",
            "password": "correct horse battery staple",
        },
    )
    second_refresh_token = second_registration_response.json()["refresh_token"]

    for _ in range(30):
        response = client.post(
            "/api/v1/auth/token-refreshes",
            json={"refresh_token": first_refresh_token},
        )

        assert response.status_code in {200, 401}

    limited_response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": first_refresh_token},
    )

    assert limited_response.status_code == 429

    error = limited_response.json()["error"]

    assert error["code"] == "rate_limit_exceeded"
    assert error["details"] == []
    assert error["request_id"]
    assert limited_response.headers["Retry-After"]

    independent_family_response = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": second_refresh_token},
    )

    assert independent_family_response.status_code == 200


def test_logout_revokes_the_current_session_and_is_repeatable(
    client,
) -> None:
    registration_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "logout-api@example.com",
            "password": "correct horse battery staple",
        },
    )
    session = registration_response.json()
    headers = {"Authorization": f"Bearer {session['access_token']}"}

    first_response = client.post(
        "/api/v1/auth/logout",
        headers=headers,
        json={"refresh_token": session["refresh_token"]},
    )
    second_response = client.post(
        "/api/v1/auth/logout",
        headers=headers,
        json={"refresh_token": session["refresh_token"]},
    )

    assert first_response.status_code == 204
    assert second_response.status_code == 204
    assert first_response.content == b""
    assert second_response.content == b""


def test_logout_rejects_missing_or_invalid_access_tokens(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": "not-a-refresh-token"},
    )

    assert response.status_code == 401

    error = response.json()["error"]

    assert error["code"] == "invalid_access_token"
    assert error["details"] == []
    assert error["request_id"]


def test_logout_rejects_malformed_access_header(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": "Basic not-a-bearer-token"},
        json={"refresh_token": "not-a-refresh-token"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_access_token"


def test_logout_rejects_invalid_access_token(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": "Bearer not-a-jwt"},
        json={"refresh_token": "not-a-refresh-token"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_access_token"


def test_logout_rejects_a_refresh_token_from_another_session(
    client,
) -> None:
    first_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "logout-first@example.com",
            "password": "correct horse battery staple",
        },
    )
    second_response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "logout-second@example.com",
            "password": "correct horse battery staple",
        },
    )
    first_session = first_response.json()
    second_session = second_response.json()

    response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {first_session['access_token']}"},
        json={"refresh_token": second_session["refresh_token"]},
    )

    assert response.status_code == 400

    error = response.json()["error"]

    assert error["code"] == "session_mismatch"
    assert error["details"] == []
    assert error["request_id"]


def test_password_reset_request_returns_generic_202_for_known_and_unknown_email(
    client,
) -> None:
    client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "reset-known-api@example.com",
            "password": "correct horse battery staple",
        },
    )

    known_response = client.post(
        "/api/v1/auth/password-reset-requests",
        json={"email": "RESET-KNOWN-API@EXAMPLE.COM"},
    )
    unknown_response = client.post(
        "/api/v1/auth/password-reset-requests",
        json={"email": "reset-unknown-api@example.com"},
    )

    assert known_response.status_code == 202
    assert unknown_response.status_code == 202
    assert known_response.json() == unknown_response.json()
    assert known_response.json()["message"] == (
        "If an account exists for that email, password-reset instructions will be sent."
    )


def test_password_reset_request_rejects_invalid_email_with_standard_422(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/password-reset-requests",
        json={"email": "not-an-email"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_password_reset_request_limits_ip_attempts(
    client,
) -> None:
    for index in range(10):
        response = client.post(
            "/api/v1/auth/password-reset-requests",
            json={"email": f"reset-ip-{index}@example.com"},
        )

        assert response.status_code == 202

    response = client.post(
        "/api/v1/auth/password-reset-requests",
        json={"email": "reset-ip-final@example.com"},
    )

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "rate_limit_exceeded"
    assert response.headers["Retry-After"]


def test_password_reset_completion_returns_204_and_rejects_replay(
    client,
    db_session,
) -> None:
    user = UserRepository(db_session).create(
        email=f"reset-api-{uuid4()}@example.com",
        password_hash=hash_password("old correct horse battery staple"),
    )
    plain_token = f"api-reset-token-{uuid4()}"
    PasswordResetTokenRepository(db_session).create(
        user_id=user.id,
        token_hash=hash_opaque_token(plain_token),
        expires_at=datetime.now(UTC) + timedelta(minutes=30),
    )

    response = client.post(
        "/api/v1/auth/password-resets",
        json={
            "reset_token": plain_token,
            "new_password": "new correct horse battery staple",
        },
    )

    replay_response = client.post(
        "/api/v1/auth/password-resets",
        json={
            "reset_token": plain_token,
            "new_password": "another correct horse battery staple",
        },
    )

    assert response.status_code == 204
    assert response.content == b""
    assert replay_response.status_code == 400
    assert replay_response.json()["error"]["code"] == "invalid_or_expired_reset_token"


def test_password_reset_completion_reuses_standard_password_validation(
    client,
    db_session,
) -> None:
    user = UserRepository(db_session).create(
        email=f"reset-validation-{uuid4()}@example.com",
        password_hash=hash_password("old correct horse battery staple"),
    )
    plain_token = f"validation-token-{uuid4()}"
    PasswordResetTokenRepository(db_session).create(
        user_id=user.id,
        token_hash=hash_opaque_token(plain_token),
        expires_at=datetime.now(UTC) + timedelta(minutes=30),
    )

    response = client.post(
        "/api/v1/auth/password-resets",
        json={"reset_token": plain_token, "new_password": "too short"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_password_reset_completion_limits_repeated_token_attempts(
    client,
) -> None:
    for _ in range(5):
        response = client.post(
            "/api/v1/auth/password-resets",
            json={
                "reset_token": "repeated-reset-token",
                "new_password": "new correct horse battery staple",
            },
        )

        assert response.status_code == 400

    response = client.post(
        "/api/v1/auth/password-resets",
        json={
            "reset_token": "repeated-reset-token",
            "new_password": "new correct horse battery staple",
        },
    )

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "rate_limit_exceeded"
    assert response.headers["Retry-After"]
