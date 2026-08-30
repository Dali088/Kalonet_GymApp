import base64
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import UserProfile

PNG_BYTES = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


def register(client) -> dict:
    response = client.post(
        "/api/v1/auth/registrations",
        json={
            "email": f"{uuid4()}@example.com",
            "password": "correct-horse-battery-staple",
        },
    )
    assert response.status_code == 201
    return response.json()


def complete_onboarding(client, session: dict) -> dict[str, str]:
    headers = {"Authorization": f"Bearer {session['access_token']}"}
    payload = {
        "goal": "maintain_weight",
        "measurements": {
            "date_of_birth": "2000-01-01",
            "sex_for_formula": "male",
            "height_cm": 180,
            "weight_kg": 80,
        },
        "activity_level": "moderately_active",
        "meal_schedule": [{"preferred_time": "08:00", "display_order": 1}],
    }
    assert (
        client.patch("/api/v1/users/me/onboarding", headers=headers, json=payload).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/users/me/onboarding-completions",
            headers=headers,
            json={"accepted_target": True},
        ).status_code
        == 201
    )
    return headers


def test_dynamic_schedule_supports_one_to_fifteen_and_reload(client) -> None:
    headers = complete_onboarding(client, register(client))

    fifteen = [
        {"preferred_time": f"{(index + 6) % 24:02d}:00", "display_order": index + 1}
        for index in range(15)
    ]
    updated = client.put(
        "/api/v1/users/me/meal-schedule",
        headers=headers,
        json={"items": fifteen},
    )

    assert updated.status_code == 200
    assert len(updated.json()["items"]) == 15
    assert all("meal_type" not in item for item in updated.json()["items"])

    reloaded = client.get("/api/v1/users/me/profile", headers=headers)
    assert reloaded.status_code == 200
    assert [item["display_order"] for item in reloaded.json()["meal_schedule"]] == list(
        range(1, 16)
    )

    reduced = client.put(
        "/api/v1/users/me/meal-schedule",
        headers=headers,
        json={
            "items": [
                {"preferred_time": "08:00", "display_order": 1},
                {"preferred_time": "19:00", "display_order": 2},
            ]
        },
    )
    assert reduced.status_code == 200
    assert [item["display_order"] for item in reduced.json()["items"]] == [1, 2]


def test_dynamic_schedule_rejects_empty_sixteen_invalid_and_gapped(client) -> None:
    headers = complete_onboarding(client, register(client))

    cases = [
        {"items": []},
        {"items": [{"preferred_time": "08:00", "display_order": index + 1} for index in range(16)]},
        {"items": [{"preferred_time": "25:00", "display_order": 1}]},
        {
            "items": [
                {"preferred_time": "08:00", "display_order": 1},
                {"preferred_time": "09:00", "display_order": 3},
            ]
        },
    ]
    for payload in cases:
        response = client.put(
            "/api/v1/users/me/meal-schedule",
            headers=headers,
            json=payload,
        )
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "validation_error"


def test_avatar_upload_replace_read_remove_and_account_cascade(
    client,
    db_session: Session,
) -> None:
    session = register(client)
    headers = complete_onboarding(client, session)
    initial_profile = client.get("/api/v1/users/me/profile", headers=headers)
    assert initial_profile.json()["user"]["avatar_present"] is False

    uploaded = client.put(
        "/api/v1/users/me/profile/avatar",
        headers=headers,
        files={"image": ("avatar.png", PNG_BYTES, "image/png")},
    )
    assert uploaded.status_code == 204
    profile = client.get("/api/v1/users/me/profile", headers=headers)
    assert profile.json()["user"]["avatar_present"] is True

    image = client.get("/api/v1/users/me/profile/avatar", headers=headers)
    assert image.status_code == 200
    assert image.headers["content-type"] == "image/png"
    assert image.content == PNG_BYTES

    invalid_type = client.put(
        "/api/v1/users/me/profile/avatar",
        headers=headers,
        files={"image": ("avatar.txt", PNG_BYTES, "text/plain")},
    )
    assert invalid_type.status_code == 422

    malformed = client.put(
        "/api/v1/users/me/profile/avatar",
        headers=headers,
        files={"image": ("avatar.png", b"not an image", "image/png")},
    )
    assert malformed.status_code == 422

    oversized = client.put(
        "/api/v1/users/me/profile/avatar",
        headers=headers,
        files={"image": ("avatar.png", b"x" * (2 * 1024 * 1024 + 1), "image/png")},
    )
    assert oversized.status_code == 422

    removed = client.delete("/api/v1/users/me/profile/avatar", headers=headers)
    assert removed.status_code == 204
    assert client.get("/api/v1/users/me/profile/avatar", headers=headers).status_code == 404

    # Re-upload before account deletion and verify the profile-owned bytes are
    # removed by the existing users -> user_profiles cascade.
    assert (
        client.put(
            "/api/v1/users/me/profile/avatar",
            headers=headers,
            files={"image": ("avatar.png", PNG_BYTES, "image/png")},
        ).status_code
        == 204
    )
    user_id = session["user"]["id"]
    delete = client.post(
        "/api/v1/users/me/account-deletions",
        headers=headers,
        json={
            "current_password": "correct-horse-battery-staple",
            "confirmation": "DELETE",
        },
    )
    assert delete.status_code == 204
    assert db_session.scalar(select(UserProfile).where(UserProfile.user_id == user_id)) is None


def test_avatar_routes_require_authentication(client) -> None:
    assert client.get("/api/v1/users/me/profile/avatar").status_code == 401
    assert (
        client.put(
            "/api/v1/users/me/profile/avatar",
            files={"image": ("avatar.png", PNG_BYTES, "image/png")},
        ).status_code
        == 401
    )
    assert client.delete("/api/v1/users/me/profile/avatar").status_code == 401


def test_profile_and_avatar_are_isolated_by_authenticated_user(client) -> None:
    account_a = register(client)
    headers_a = complete_onboarding(client, account_a)
    account_b = register(client)
    headers_b = complete_onboarding(client, account_b)

    updated = client.patch(
        "/api/v1/users/me/profile",
        headers=headers_a,
        json={"nickname": "pakpak"},
    )
    assert updated.status_code == 200
    uploaded = client.put(
        "/api/v1/users/me/profile/avatar",
        headers=headers_a,
        files={"image": ("avatar.png", PNG_BYTES, "image/png")},
    )
    assert uploaded.status_code == 204

    profile_a = client.get("/api/v1/users/me/profile", headers=headers_a)
    profile_b = client.get("/api/v1/users/me/profile", headers=headers_b)
    assert profile_a.status_code == profile_b.status_code == 200
    assert profile_a.json()["user"]["email"] == account_a["user"]["email"]
    assert profile_b.json()["user"]["email"] == account_b["user"]["email"]
    assert profile_a.json()["user"]["nickname"] == "pakpak"
    assert profile_b.json()["user"]["nickname"] is None
    assert profile_a.json()["user"]["avatar_present"] is True
    assert profile_b.json()["user"]["avatar_present"] is False

    avatar_a = client.get("/api/v1/users/me/profile/avatar", headers=headers_a)
    avatar_b = client.get("/api/v1/users/me/profile/avatar", headers=headers_b)
    assert avatar_a.status_code == 200
    assert avatar_a.content == PNG_BYTES
    assert avatar_b.status_code == 404
