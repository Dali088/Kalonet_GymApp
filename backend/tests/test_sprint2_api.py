from decimal import Decimal
from uuid import UUID

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import NutritionTarget, RefreshSession, User, UserProfile
from kalonet_backend.repositories.nutrition_targets import NutritionTargetRepository
from kalonet_backend.schemas.personalization import NutritionRecalculationRequest
from kalonet_backend.services.onboarding import ProfileService


def register(client, email: str = "sprint2@example.com") -> dict:
    response = client.post(
        "/api/v1/auth/registrations",
        json={"email": email, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == 201
    return response.json()


def auth_headers(session: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {session['access_token']}"}


def onboarding_payload() -> dict:
    return {
        "goal": "weight_loss",
        "measurements": {
            "date_of_birth": "2004-03-14",
            "sex_for_formula": "male",
            "height_cm": 180,
            "weight_kg": 82.5,
        },
        "activity_level": "moderately_active",
        "dietary_preferences": ["halal", "vegetarian"],
        "meal_schedule": [
            {"meal_type": "breakfast", "preferred_time": "08:00", "display_order": 1},
            {"meal_type": "dinner", "preferred_time": "20:00", "display_order": 2},
        ],
    }


def test_onboarding_profile_target_and_settings_flow(client) -> None:
    session = register(client)
    headers = auth_headers(session)

    state = client.get("/api/v1/users/me/onboarding", headers=headers)
    assert state.status_code == 200
    assert state.json()["status"] == "not_started"

    draft = client.patch(
        "/api/v1/users/me/onboarding",
        headers=headers,
        json=onboarding_payload(),
    )
    assert draft.status_code == 200
    assert draft.json()["status"] == "in_progress"
    assert draft.json()["missing_fields"] == []

    preview = client.post(
        "/api/v1/users/me/nutrition-target-previews",
        headers=headers,
    )
    assert preview.status_code == 200
    assert preview.json()["target"]["is_active"] is False

    completion = client.post(
        "/api/v1/users/me/onboarding-completions",
        headers=headers,
        json={"accepted_target": True},
    )
    assert completion.status_code == 201
    old_target_id = completion.json()["nutrition_target"]["id"]

    current = client.get(
        "/api/v1/users/me/nutrition-targets/current",
        headers=headers,
    )
    assert current.status_code == 200
    assert current.json()["id"] == old_target_id

    profile = client.get("/api/v1/users/me/profile", headers=headers)
    assert profile.status_code == 200
    assert profile.json()["calculation_inputs"]["goal"] == "weight_loss"

    recalculation = client.post(
        "/api/v1/users/me/nutrition-target-recalculations",
        headers=headers,
        json={
            "goal": "maintain_weight",
            "date_of_birth": "2004-03-14",
            "formula_sex": "male",
            "height_cm": 180,
            "weight_kg": 80,
            "activity_level": "moderately_active",
        },
    )
    assert recalculation.status_code == 201
    assert recalculation.json()["previous_target_id"] == old_target_id

    preferences = client.put(
        "/api/v1/users/me/dietary-preferences",
        headers=headers,
        json={"preferences": ["vegan"]},
    )
    assert preferences.status_code == 200
    assert preferences.json()["preferences"] == ["vegan"]

    schedule = client.put(
        "/api/v1/users/me/meal-schedule",
        headers=headers,
        json={"items": [{"meal_type": "lunch", "preferred_time": "13:00", "display_order": 1}]},
    )
    assert schedule.status_code == 200
    assert schedule.json()["items"][0]["meal_type"] == "lunch"

    settings = client.get("/api/v1/users/me/settings", headers=headers)
    assert settings.status_code == 200
    assert settings.json()["measurement_system"] == "metric"

    updated_settings = client.patch(
        "/api/v1/users/me/settings",
        headers=headers,
        json={"theme_preference": "dark", "time_zone": "Africa/Tunis"},
    )
    assert updated_settings.status_code == 200
    assert updated_settings.json()["theme_preference"] == "dark"


def test_sprint2_protected_routes_require_access_token(client) -> None:
    response = client.get("/api/v1/users/me/onboarding")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_access_token"


def test_onboarding_rejects_unknown_preferences_and_repeated_completion(client) -> None:
    session = register(client, email="validation@example.com")
    headers = auth_headers(session)
    payload = onboarding_payload()
    payload["dietary_preferences"] = ["not-a-real-preference"]

    invalid = client.patch(
        "/api/v1/users/me/onboarding",
        headers=headers,
        json=payload,
    )
    assert invalid.status_code == 422

    assert (
        client.patch(
            "/api/v1/users/me/onboarding",
            headers=headers,
            json=onboarding_payload(),
        ).status_code
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
    repeated = client.post(
        "/api/v1/users/me/onboarding-completions",
        headers=headers,
        json={"accepted_target": True},
    )
    assert repeated.status_code == 409


def test_settings_reject_unknown_time_zone(client) -> None:
    session = register(client, email="settings-validation@example.com")
    response = client.patch(
        "/api/v1/users/me/settings",
        headers=auth_headers(session),
        json={"time_zone": "Not/An_IANA_Zone"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_recalculation_rolls_back_profile_when_target_creation_fails(
    client,
    db_session: Session,
    monkeypatch,
) -> None:
    session = register(client, email="rollback@example.com")
    headers = auth_headers(session)
    assert (
        client.patch(
            "/api/v1/users/me/onboarding",
            headers=headers,
            json=onboarding_payload(),
        ).status_code
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

    def fail_create(*args, **kwargs):
        raise RuntimeError("simulated target insert failure")

    monkeypatch.setattr(NutritionTargetRepository, "create", fail_create)
    request = NutritionRecalculationRequest(
        goal="weight_loss",
        date_of_birth="2004-03-14",
        formula_sex="male",
        height_cm=180,
        weight_kg=84,
        activity_level="very_active",
    )

    with pytest.raises(RuntimeError, match="simulated target insert failure"):
        ProfileService(db_session).recalculate(UUID(session["user"]["id"]), request)

    db_session.expire_all()
    profile = db_session.scalar(
        select(UserProfile).where(UserProfile.user_id == UUID(session["user"]["id"]))
    )
    active_targets = db_session.scalars(
        select(NutritionTarget).where(
            NutritionTarget.user_id == UUID(session["user"]["id"]),
            NutritionTarget.deactivated_at.is_(None),
        )
    ).all()
    assert profile is not None
    assert profile.weight_kg == Decimal("82.50")
    assert len(active_targets) == 1


def test_password_change_revokes_sessions_and_account_deletion_cascades(
    client,
    db_session: Session,
) -> None:
    session = register(client, email="delete-me@example.com")
    headers = auth_headers(session)
    assert (
        client.patch(
            "/api/v1/users/me/onboarding",
            headers=headers,
            json=onboarding_payload(),
        ).status_code
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

    changed = client.post(
        "/api/v1/auth/password-changes",
        headers=headers,
        json={
            "current_password": "correct-horse-battery-staple",
            "new_password": "another-correct-horse-passphrase",
        },
    )
    assert changed.status_code == 204

    old_refresh = client.post(
        "/api/v1/auth/token-refreshes",
        json={"refresh_token": session["refresh_token"]},
    )
    assert old_refresh.status_code == 401

    new_session = client.post(
        "/api/v1/auth/sessions",
        json={
            "email": "delete-me@example.com",
            "password": "another-correct-horse-passphrase",
        },
    )
    assert new_session.status_code == 200
    new_headers = auth_headers(new_session.json())
    user_id = new_session.json()["user"]["id"]

    deleted = client.post(
        "/api/v1/users/me/account-deletions",
        headers=new_headers,
        json={
            "current_password": "another-correct-horse-passphrase",
            "confirmation": "DELETE",
        },
    )
    assert deleted.status_code == 204
    parsed_user_id = UUID(user_id)
    assert db_session.scalar(select(User).where(User.id == parsed_user_id)) is None
    assert (
        db_session.scalar(select(NutritionTarget).where(NutritionTarget.user_id == parsed_user_id))
        is None
    )
    assert (
        db_session.scalar(select(RefreshSession).where(RefreshSession.user_id == parsed_user_id))
        is None
    )
