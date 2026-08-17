from datetime import date

from sqlalchemy import func, select

from kalonet_backend.models import ActivityEntry, DailyStepRecord, Meal, MealItem, WaterEntry


def register(client, email: str) -> dict:
    response = client.post(
        "/api/v1/auth/registrations",
        json={"email": email, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == 201
    return response.json()


def complete_onboarding(client, session: dict) -> dict[str, str]:
    headers = {"Authorization": f"Bearer {session['access_token']}"}
    payload = {
        "goal": "weight_loss",
        "measurements": {
            "date_of_birth": "2004-03-14",
            "sex_for_formula": "male",
            "height_cm": 180,
            "weight_kg": 82.5,
        },
        "activity_level": "moderately_active",
        "dietary_preferences": ["halal"],
        "meal_schedule": [
            {"meal_type": "breakfast", "preferred_time": "08:00", "display_order": 1}
        ],
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


def meal_payload() -> dict:
    return {
        "record_date": "2026-08-10",
        "meal_type": "lunch",
        "name": "Lunch",
        "recorded_time": "13:10:00",
        "items": [
            {
                "name": "Rice",
                "quantity": 1,
                "serving_description": "one bowl",
                "nutrition": {
                    "calories_kcal": 500,
                    "protein_g": 20,
                    "carbohydrate_g": 80,
                    "fat_g": 10,
                },
            }
        ],
    }


def test_sprint3_tracking_crud_and_dashboard(client) -> None:
    headers = complete_onboarding(client, register(client, "tracking@example.com"))

    created = client.post(
        "/api/v1/users/me/meals",
        headers={**headers, "Idempotency-Key": "meal-1"},
        json=meal_payload(),
    )
    assert created.status_code == 201
    meal = created.json()
    assert meal["totals"]["calories_kcal"] == 500

    replay = client.post(
        "/api/v1/users/me/meals",
        headers={**headers, "Idempotency-Key": "meal-1"},
        json=meal_payload(),
    )
    assert replay.status_code == 201
    assert replay.json()["id"] == meal["id"]

    conflict_payload = meal_payload()
    conflict_payload["name"] = "Changed"
    assert (
        client.post(
            "/api/v1/users/me/meals",
            headers={**headers, "Idempotency-Key": "meal-1"},
            json=conflict_payload,
        ).json()["error"]["code"]
        == "idempotency_key_conflict"
    )

    water = client.post(
        "/api/v1/users/me/water-entries",
        headers={**headers, "Idempotency-Key": "water-1"},
        json={"amount_ml": 500, "recorded_at": "2026-08-10T08:00:00Z"},
    )
    assert water.status_code == 201
    assert (
        client.put(
            "/api/v1/users/me/daily-steps/2026-08-10",
            headers=headers,
            json={"step_count": 6420, "source": "manual"},
        ).status_code
        == 200
    )
    activity = client.post(
        "/api/v1/users/me/activities",
        headers={**headers, "Idempotency-Key": "activity-1"},
        json={
            "activity_type": "walking",
            "name": "Walk",
            "duration_minutes": 30,
            "estimated_calories_kcal": 120,
            "recorded_at": "2026-08-10T17:00:00Z",
        },
    )
    assert activity.status_code == 201

    dashboard = client.get(
        "/api/v1/users/me/daily-dashboard",
        headers=headers,
        params={"date": "2026-08-10"},
    )
    assert dashboard.status_code == 200
    assert dashboard.json()["meals"]["logged_item_count"] == 1
    assert dashboard.json()["water"]["consumed_ml"] == 500
    assert dashboard.json()["steps"]["count"] == 6420

    listed = client.get("/api/v1/users/me/meals", headers=headers, params={"date": "2026-08-10"})
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1


def test_sprint3_ownership_and_future_date(client) -> None:
    first = complete_onboarding(client, register(client, "owner-one@example.com"))
    second = complete_onboarding(client, register(client, "owner-two@example.com"))
    created = client.post("/api/v1/users/me/meals", headers=first, json=meal_payload())
    meal_id = created.json()["id"]

    foreign = client.get(f"/api/v1/users/me/meals/{meal_id}", headers=second)
    assert foreign.status_code == 404

    future = meal_payload()
    future["record_date"] = "2099-01-01"
    assert (
        client.post("/api/v1/users/me/meals", headers=first, json=future).json()["error"]["code"]
        == "future_date_not_allowed"
    )


def test_empty_dashboard_requires_onboarding(client) -> None:
    session = register(client, "not-onboarded@example.com")
    response = client.get(
        "/api/v1/users/me/daily-dashboard",
        headers={"Authorization": f"Bearer {session['access_token']}"},
        params={"date": str(date.today())},
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "onboarding_required"


def test_account_deletion_cascades_sprint3_records(client, db_session) -> None:
    session = register(client, "delete-tracking@example.com")
    headers = complete_onboarding(client, session)
    assert (
        client.post("/api/v1/users/me/meals", headers=headers, json=meal_payload()).status_code
        == 201
    )
    assert (
        client.post(
            "/api/v1/users/me/water-entries",
            headers=headers,
            json={"amount_ml": 300, "recorded_at": "2026-08-10T08:00:00Z"},
        ).status_code
        == 201
    )
    assert (
        client.put(
            "/api/v1/users/me/daily-steps/2026-08-10",
            headers=headers,
            json={"step_count": 10, "source": "manual"},
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/users/me/activities",
            headers=headers,
            json={
                "activity_type": "walking",
                "name": "Walk",
                "duration_minutes": 10,
                "recorded_at": "2026-08-10T08:00:00Z",
            },
        ).status_code
        == 201
    )

    deleted = client.post(
        "/api/v1/users/me/account-deletions",
        headers=headers,
        json={"current_password": "correct-horse-battery-staple", "confirmation": "DELETE"},
    )
    assert deleted.status_code == 204
    assert db_session.scalar(select(func.count()).select_from(Meal)) == 0
    assert db_session.scalar(select(func.count()).select_from(MealItem)) == 0
    assert db_session.scalar(select(func.count()).select_from(WaterEntry)) == 0
    assert db_session.scalar(select(func.count()).select_from(DailyStepRecord)) == 0
    assert db_session.scalar(select(func.count()).select_from(ActivityEntry)) == 0
