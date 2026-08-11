def test_registration_returns_201_and_session(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "ApiUser@Example.COM",
            "password": "correct horse battery staple",
        },
    )

    assert response.status_code == 201

    payload = response.json()

    assert payload["token_type"] == "bearer"
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["access_token_expires_in_seconds"] == 900

    assert payload["user"]["email"] == "apiuser@example.com"
    assert payload["user"]["onboarding_completed"] is False


def test_registration_returns_409_for_existing_email(
    client,
) -> None:
    body = {
        "email": "duplicate-api@example.com",
        "password": "correct horse battery staple",
    }

    first_response = client.post(
        "/api/v1/auth/registrations",
        json=body,
    )

    second_response = client.post(
        "/api/v1/auth/registrations",
        json=body,
    )

    assert first_response.status_code == 201
    assert second_response.status_code == 409

    payload = second_response.json()

    assert payload["error"]["code"] == ("email_already_registered")
    assert payload["error"]["details"] == []
    assert payload["error"]["request_id"]


def test_registration_returns_422_for_invalid_email(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "not-an-email",
            "password": "correct horse battery staple",
        },
    )

    assert response.status_code == 422

    payload = response.json()

    assert payload["error"]["code"] == "validation_error"
    assert payload["error"]["message"] == ("Request validation failed.")
    assert payload["error"]["request_id"]
    assert payload["error"]["details"]

    assert any(detail["field"] == "email" for detail in payload["error"]["details"])


def test_registration_returns_422_for_short_password(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "valid@example.com",
            "password": "too-short",
        },
    )

    assert response.status_code == 422

    payload = response.json()

    assert payload["error"]["code"] == "validation_error"
    assert payload["error"]["request_id"]
    assert payload["error"]["details"]

    assert any(detail["field"] == "password" for detail in payload["error"]["details"])


def test_registration_returns_422_for_blocklisted_password(
    client,
) -> None:
    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "blocked-password@example.com",
            "password": "Password1234567",
        },
    )

    assert response.status_code == 422

    payload = response.json()

    assert payload["error"]["code"] == "validation_error"
    assert payload["error"]["request_id"]
    assert any(detail["field"] == "password" for detail in payload["error"]["details"])


def test_registration_returns_429_after_five_attempts_from_same_ip(
    client,
) -> None:
    for index in range(5):
        response = client.post(
            "/api/v1/auth/registrations",
            json={
                "email": f"rate-limit-{index}@example.com",
                "password": "correct horse battery staple",
            },
        )

        assert response.status_code == 201

    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": "rate-limit-blocked@example.com",
            "password": "correct horse battery staple",
        },
    )

    assert response.status_code == 429

    payload = response.json()

    assert payload["error"]["code"] == "rate_limit_exceeded"
    assert payload["error"]["details"] == []
    assert payload["error"]["request_id"]
    assert response.headers["Retry-After"]
    assert int(response.headers["Retry-After"]) > 0


def test_registration_rate_limit_counts_body_validation_failures(
    client,
) -> None:
    for _ in range(5):
        response = client.post(
            "/api/v1/auth/registrations",
            content="{not-valid-json",
            headers={"content-type": "application/json"},
        )

        assert response.status_code == 422

    response = client.post(
        "/api/v1/auth/registrations",
        content="{not-valid-json",
        headers={"content-type": "application/json"},
    )

    assert response.status_code == 429

    payload = response.json()

    assert payload["error"]["code"] == "rate_limit_exceeded"
    assert payload["error"]["details"] == []
    assert payload["error"]["request_id"]
    assert response.headers["Retry-After"]
