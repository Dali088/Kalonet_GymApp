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
