from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import NutritionTarget


class NutritionTargetRepository:
    """Persistence operations for active and historical nutrition targets."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get_active(self, user_id: UUID, *, for_update: bool = False) -> NutritionTarget | None:
        statement = select(NutritionTarget).where(
            NutritionTarget.user_id == user_id,
            NutritionTarget.deactivated_at.is_(None),
        )
        if for_update:
            statement = statement.with_for_update()
        return self._session.scalar(statement)

    def create(
        self,
        *,
        user_id: UUID,
        goal: str,
        sex_for_formula: str,
        age_years: int,
        height_cm: Decimal,
        weight_kg: Decimal,
        activity_level: str,
        activity_multiplier: Decimal,
        bmr_kcal: Decimal,
        tdee_kcal: Decimal,
        goal_adjustment_kcal: int,
        daily_calories: int,
        protein_g: int,
        carbohydrate_g: int,
        fat_g: int,
        rule_version: str,
        effective_from: date,
    ) -> NutritionTarget:
        target = NutritionTarget(
            user_id=user_id,
            goal=goal,
            sex_for_formula=sex_for_formula,
            age_years=age_years,
            height_cm=height_cm,
            weight_kg=weight_kg,
            activity_level=activity_level,
            activity_multiplier=activity_multiplier,
            bmr_kcal=bmr_kcal,
            tdee_kcal=tdee_kcal,
            goal_adjustment_kcal=goal_adjustment_kcal,
            daily_calories=daily_calories,
            protein_g=protein_g,
            carbohydrate_g=carbohydrate_g,
            fat_g=fat_g,
            rule_version=rule_version,
            effective_from=effective_from,
        )
        self._session.add(target)
        self._session.flush()
        return target

    def deactivate(self, target: NutritionTarget, *, deactivated_at: datetime) -> None:
        target.deactivated_at = deactivated_at
        self._session.flush()
