from datetime import UTC, date, datetime

from sqlalchemy import select

from kalonet_backend.models import Meal, MealItem, User, UserProgression
from kalonet_backend.services.gamification import _public_display_name


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


def test_profile_nickname_is_trimmed_and_clearable(client) -> None:
    headers = complete_onboarding(client, register(client, "nickname@example.com"))

    updated = client.patch(
        "/api/v1/users/me/profile", headers=headers, json={"nickname": "  Ada  "}
    )
    assert updated.status_code == 200
    assert updated.json()["user"]["nickname"] == "Ada"

    cleared = client.patch("/api/v1/users/me/profile", headers=headers, json={"nickname": None})
    assert cleared.status_code == 200
    assert cleared.json()["user"]["nickname"] is None

    blank = client.patch("/api/v1/users/me/profile", headers=headers, json={"nickname": "  "})
    assert blank.status_code == 422
    assert blank.json()["error"]["code"] == "validation_error"


def test_leaderboard_uses_duplicate_nicknames_and_safe_fallback(client, db_session) -> None:
    first_email = "leaderboard-first@example.com"
    second_email = "leaderboard-second@example.com"
    fallback_email = "leaderboard-fallback@example.com"
    first = complete_onboarding(client, register(client, first_email))
    second = complete_onboarding(client, register(client, second_email))
    complete_onboarding(client, register(client, fallback_email))

    for headers in (first, second):
        response = client.patch(
            "/api/v1/users/me/profile",
            headers=headers,
            json={"nickname": "IronDali"},
        )
        assert response.status_code == 200

    first_user = db_session.scalar(select(User).where(User.email == first_email))
    assert first_user is not None
    db_session.add(UserProgression(user_id=first_user.id, total_xp=8420))
    db_session.flush()

    leaderboard = client.get(
        "/api/v1/users/me/gamification/leaderboard",
        headers=second,
        params={"limit": 100},
    )
    assert leaderboard.status_code == 200
    rows = leaderboard.json()["items"]
    assert rows[0]["display_name"] == "IronDali"
    assert rows[0]["total_xp"] == 8420
    assert rows[0]["position"] == 1
    assert sum(row["display_name"] == "IronDali" for row in rows) == 2
    assert any(row["is_current_user"] and row["display_name"] == "IronDali" for row in rows)
    assert any(row["display_name"] == "Kalonet member" for row in rows)
    assert all("email" not in row for row in rows)


def test_public_leaderboard_name_rejects_blank_values() -> None:
    assert _public_display_name(None) == "Kalonet member"
    assert _public_display_name("") == "Kalonet member"
    assert _public_display_name("  ") == "Kalonet member"
    assert _public_display_name("  IronDali  ") == "IronDali"


def test_tracking_before_onboarding_keeps_existing_write_behavior(client) -> None:
    session = register(client, "pre-onboarding-tracking@example.com")
    headers = {"Authorization": f"Bearer {session['access_token']}"}

    created = client.post("/api/v1/users/me/meals", headers=headers, json=meal_payload())
    assert created.status_code == 201

    summary = client.get(
        "/api/v1/users/me/gamification",
        headers=headers,
        params={"date": "2026-08-10"},
    )
    assert summary.status_code == 403
    assert summary.json()["error"]["code"] == "onboarding_required"


def test_daily_steps_support_atomic_addition_and_limit(client) -> None:
    headers = complete_onboarding(client, register(client, "steps-add@example.com"))
    assert (
        client.put(
            "/api/v1/users/me/daily-steps/2026-08-24",
            headers=headers,
            json={"step_count": 100, "source": "manual"},
        ).status_code
        == 200
    )

    added = client.post(
        "/api/v1/users/me/daily-steps/2026-08-24/increments",
        headers=headers,
        json={"increment": 50},
    )
    assert added.status_code == 200
    assert added.json()["step_count"] == 150

    too_many = client.post(
        "/api/v1/users/me/daily-steps/2026-08-24/increments",
        headers=headers,
        json={"increment": 200000},
    )
    assert too_many.status_code == 409
    assert too_many.json()["error"]["code"] == "daily_steps_limit_exceeded"


def test_gamification_awards_each_daily_quest_once_and_hides_email(client) -> None:
    first = complete_onboarding(client, register(client, "gamification-one@example.com"))
    second = complete_onboarding(client, register(client, "gamification-two@example.com"))
    date = "2026-08-24"

    meal = meal_payload()
    meal["record_date"] = date
    assert client.post("/api/v1/users/me/meals", headers=first, json=meal).status_code == 201
    assert (
        client.post(
            "/api/v1/users/me/water-entries",
            headers=first,
            json={"amount_ml": 2500, "recorded_at": f"{date}T08:00:00Z"},
        ).status_code
        == 201
    )
    assert (
        client.post(
            f"/api/v1/users/me/daily-steps/{date}/increments",
            headers=first,
            json={"increment": 10000},
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/users/me/activities",
            headers=first,
            json={
                "activity_type": "walking",
                "name": "Walk",
                "duration_minutes": 20,
                "recorded_at": f"{date}T10:00:00Z",
            },
        ).status_code
        == 201
    )

    summary = client.get("/api/v1/users/me/gamification", headers=first, params={"date": date})
    assert summary.status_code == 200
    body = summary.json()
    assert body["total_xp"] == 50
    assert all(quest["completed"] and quest["awarded"] for quest in body["daily_quests"])
    assert body["unlocked_badge_count"] >= 4

    repeated = client.get("/api/v1/users/me/gamification", headers=first, params={"date": date})
    assert repeated.json()["total_xp"] == 50

    leaderboard = client.get(
        "/api/v1/users/me/gamification/leaderboard", headers=second, params={"limit": 10}
    )
    assert leaderboard.status_code == 200
    assert all("email" not in row for row in leaderboard.json()["items"])


def test_gamification_summary_does_not_back_award_historical_tracking(client, db_session) -> None:
    email = "historical-gamification@example.com"
    headers = complete_onboarding(client, register(client, email))
    user = db_session.scalar(select(User).where(User.email == email))
    assert user is not None
    db_session.add(
        Meal(
            user_id=user.id,
            record_date=date(2026, 8, 10),
            meal_type="lunch",
            name="Historical lunch",
            recorded_at=datetime(2026, 8, 10, 13, tzinfo=UTC),
            items=[
                MealItem(
                    display_order=1,
                    name="Rice",
                    quantity=1,
                    serving_description="one bowl",
                    calories_kcal=500,
                    protein_g=20,
                    carbohydrate_g=80,
                    fat_g=10,
                )
            ],
        )
    )
    db_session.flush()

    summary = client.get(
        "/api/v1/users/me/gamification", headers=headers, params={"date": "2026-08-10"}
    )
    assert summary.status_code == 200
    body = summary.json()
    assert body["total_xp"] == 0
    daily_meal = next(quest for quest in body["daily_quests"] if quest["code"] == "daily_meal")
    assert daily_meal["completed"] is True
    assert daily_meal["awarded"] is False
    assert body["unlocked_badge_count"] == 0
