from datetime import date, time
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from kalonet_backend.models import (
    DietaryPreference,
    MealScheduleItem,
    NutritionTarget,
    User,
    UserDietaryPreference,
)


def create_user(session: Session) -> User:
    user = User(email=f"{uuid4()}@example.com", password_hash="hash")
    session.add(user)
    session.flush()
    return user


def test_personalization_definitions_are_seeded(db_session: Session) -> None:
    codes = db_session.scalars(
        select(DietaryPreference.code).order_by(DietaryPreference.code)
    ).all()

    assert codes == [
        "gluten_free",
        "halal",
        "lactose_free",
        "pescatarian",
        "vegan",
        "vegetarian",
    ]


def test_junction_and_schedule_constraints_are_database_enforced(db_session: Session) -> None:
    user = create_user(db_session)
    preference = db_session.scalar(
        select(DietaryPreference).where(DietaryPreference.code == "halal")
    )
    assert preference is not None

    db_session.add(
        UserDietaryPreference(
            user_id=user.id,
            dietary_preference_id=preference.id,
        )
    )
    db_session.flush()
    db_session.add(
        UserDietaryPreference(
            user_id=user.id,
            dietary_preference_id=preference.id,
        )
    )
    with pytest.raises(IntegrityError):
        db_session.flush()
    db_session.rollback()
    user = create_user(db_session)

    schedule = MealScheduleItem(
        user_id=user.id,
        meal_type="breakfast",
        preferred_time=time(8, 0),
        display_order=1,
    )
    db_session.add(schedule)
    db_session.flush()
    db_session.add(
        MealScheduleItem(
            user_id=user.id,
            meal_type="lunch",
            preferred_time=time(13, 0),
            display_order=1,
        )
    )
    with pytest.raises(IntegrityError):
        db_session.flush()


def test_only_one_active_target_is_allowed(db_session: Session) -> None:
    user = create_user(db_session)
    values = {
        "user_id": user.id,
        "goal": "maintain_weight",
        "sex_for_formula": "male",
        "age_years": 22,
        "height_cm": Decimal("180"),
        "weight_kg": Decimal("82.5"),
        "activity_level": "moderately_active",
        "activity_multiplier": Decimal("1.550"),
        "bmr_kcal": Decimal("1800.00"),
        "tdee_kcal": Decimal("2790.00"),
        "goal_adjustment_kcal": 0,
        "daily_calories": 2790,
        "protein_g": 165,
        "carbohydrate_g": 300,
        "fat_g": 75,
        "rule_version": "nutrition_rules_v1",
        "effective_from": date(2026, 8, 1),
    }
    db_session.add_all([NutritionTarget(**values), NutritionTarget(**values)])

    with pytest.raises(IntegrityError):
        db_session.flush()

    db_session.rollback()
    assert (
        db_session.scalar(
            select(func.count())
            .select_from(NutritionTarget)
            .where(NutritionTarget.user_id == user.id)
        )
        == 0
    )
