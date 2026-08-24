from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.orm import Session

from kalonet_backend.models import (
    ActivityEntry,
    DailyStepRecord,
    Meal,
    User,
    UserBadge,
    UserProfile,
    UserProgression,
    WaterEntry,
    XpAward,
)


class GamificationRepository:
    """Persistence queries for server-authoritative progression state."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def ensure_progression(self, user_id: UUID) -> UserProgression:
        statement = (
            postgresql_insert(UserProgression)
            .values(user_id=user_id, total_xp=0)
            .on_conflict_do_nothing(index_elements=[UserProgression.user_id])
        )
        self.session.execute(statement)
        self.session.flush()
        progression = self.session.scalar(
            select(UserProgression).where(UserProgression.user_id == user_id)
        )
        if progression is None:  # pragma: no cover - protected user must have a row
            raise RuntimeError("Progression row was not created.")
        return progression

    def progression(self, user_id: UUID) -> UserProgression:
        progression = self.session.scalar(
            select(UserProgression).where(UserProgression.user_id == user_id)
        )
        return progression or self.ensure_progression(user_id)

    def award_xp(self, user_id: UUID, reason_code: str, period_key: str, amount: int) -> bool:
        """Insert one ledger row and atomically add its amount exactly once."""

        award_statement = (
            postgresql_insert(XpAward)
            .values(
                id=uuid4(),
                user_id=user_id,
                reason_code=reason_code,
                period_key=period_key,
                amount=amount,
            )
            .on_conflict_do_nothing(
                index_elements=[XpAward.user_id, XpAward.reason_code, XpAward.period_key]
            )
            .returning(XpAward.id)
        )
        result = self.session.execute(award_statement)
        if result.first() is None:
            return False

        progression_statement = (
            postgresql_insert(UserProgression)
            .values(user_id=user_id, total_xp=amount)
            .on_conflict_do_update(
                index_elements=[UserProgression.user_id],
                set_={
                    "total_xp": UserProgression.total_xp + amount,
                    "updated_at": func.now(),
                },
            )
        )
        self.session.execute(progression_statement)
        self.session.flush()
        return True

    def unlock_badge(self, user_id: UUID, badge_code: str) -> bool:
        statement = (
            postgresql_insert(UserBadge)
            .values(id=uuid4(), user_id=user_id, badge_code=badge_code)
            .on_conflict_do_nothing(index_elements=[UserBadge.user_id, UserBadge.badge_code])
            .returning(UserBadge.id)
        )
        result = self.session.execute(statement)
        self.session.flush()
        return result.first() is not None

    def awarded_codes(self, user_id: UUID, period_key: str) -> set[str]:
        values = self.session.scalars(
            select(XpAward.reason_code).where(
                XpAward.user_id == user_id, XpAward.period_key == period_key
            )
        )
        return set(values)

    def unlocked_badges(self, user_id: UUID) -> dict[str, object]:
        rows = self.session.execute(
            select(UserBadge.badge_code, UserBadge.unlocked_at).where(UserBadge.user_id == user_id)
        )
        return {row[0]: row[1] for row in rows}

    def daily_metrics(self, user_id: UUID, record_date: date) -> tuple[int, int, int, int]:
        meals = int(
            self.session.scalar(
                select(func.count(Meal.id)).where(
                    Meal.user_id == user_id, Meal.record_date == record_date
                )
            )
            or 0
        )
        water = int(
            self.session.scalar(
                select(func.coalesce(func.sum(WaterEntry.amount_ml), 0)).where(
                    WaterEntry.user_id == user_id, WaterEntry.record_date == record_date
                )
            )
            or 0
        )
        steps = int(
            self.session.scalar(
                select(func.coalesce(DailyStepRecord.step_count, 0)).where(
                    DailyStepRecord.user_id == user_id,
                    DailyStepRecord.record_date == record_date,
                )
            )
            or 0
        )
        activities = int(
            self.session.scalar(
                select(func.count(ActivityEntry.id)).where(
                    ActivityEntry.user_id == user_id,
                    ActivityEntry.record_date == record_date,
                )
            )
            or 0
        )
        return meals, water, steps, activities

    def weekly_metrics(
        self, user_id: UUID, start: date, end: date, water_target: int, step_target: int
    ) -> tuple[int, int, int]:
        meal_days = int(
            self.session.scalar(
                select(func.count(func.distinct(Meal.record_date))).where(
                    Meal.user_id == user_id,
                    Meal.record_date >= start,
                    Meal.record_date <= end,
                )
            )
            or 0
        )
        water_rows = self.session.execute(
            select(WaterEntry.record_date, func.sum(WaterEntry.amount_ml))
            .where(
                WaterEntry.user_id == user_id,
                WaterEntry.record_date >= start,
                WaterEntry.record_date <= end,
            )
            .group_by(WaterEntry.record_date)
        )
        hydration_days = sum(1 for row in water_rows if int(row[1] or 0) >= water_target)
        step_days = int(
            self.session.scalar(
                select(func.count(DailyStepRecord.record_date)).where(
                    DailyStepRecord.user_id == user_id,
                    DailyStepRecord.record_date >= start,
                    DailyStepRecord.record_date <= end,
                    DailyStepRecord.step_count >= step_target,
                )
            )
            or 0
        )
        return meal_days, hydration_days, step_days

    def history_metrics(
        self, user_id: UUID, water_target: int, step_target: int
    ) -> tuple[bool, bool, bool, bool, int, int, int, int]:
        first_meal = self._exists(Meal, user_id)
        first_water = self._exists(WaterEntry, user_id)
        first_steps = bool(
            self.session.scalar(
                select(DailyStepRecord.id)
                .where(
                    DailyStepRecord.user_id == user_id,
                    DailyStepRecord.step_count >= step_target,
                )
                .limit(1)
            )
        )
        first_activity = self._exists(ActivityEntry, user_id)
        meal_days = self._distinct_days(Meal, user_id)
        hydration_days = self._hydration_days(user_id, water_target)
        step_days = int(
            self.session.scalar(
                select(func.count(func.distinct(DailyStepRecord.record_date))).where(
                    DailyStepRecord.user_id == user_id,
                    DailyStepRecord.step_count >= step_target,
                )
            )
            or 0
        )
        activity_days = self._distinct_days(ActivityEntry, user_id)
        return (
            first_meal,
            first_water,
            first_steps,
            first_activity,
            meal_days,
            hydration_days,
            step_days,
            activity_days,
        )

    def leaderboard_rows(
        self, limit: int, offset: int
    ) -> tuple[list[tuple[UUID, str | None, int, int]], int]:
        xp_value = func.coalesce(UserProgression.total_xp, 0)
        rank_value = func.rank().over(order_by=xp_value.desc())
        statement = (
            select(User.id, UserProfile.nickname, xp_value, rank_value)
            .select_from(User)
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .outerjoin(UserProgression, UserProgression.user_id == User.id)
            .where(User.onboarding_completed_at.is_not(None))
            .order_by(xp_value.desc(), User.id)
            .offset(offset)
            .limit(limit)
        )
        rows = [
            (row[0], row[1], int(row[2]), int(row[3])) for row in self.session.execute(statement)
        ]
        total = int(
            self.session.scalar(
                select(func.count())
                .select_from(User)
                .where(User.onboarding_completed_at.is_not(None))
            )
            or 0
        )
        return rows, total

    def leaderboard_position(self, user_id: UUID) -> tuple[int, int]:
        progression = self.progression(user_id)
        xp_value = func.coalesce(UserProgression.total_xp, 0)
        higher = int(
            self.session.scalar(
                select(func.count())
                .select_from(User)
                .outerjoin(UserProgression, UserProgression.user_id == User.id)
                .where(
                    User.onboarding_completed_at.is_not(None),
                    xp_value > progression.total_xp,
                )
            )
            or 0
        )
        total = int(
            self.session.scalar(
                select(func.count())
                .select_from(User)
                .where(User.onboarding_completed_at.is_not(None))
            )
            or 0
        )
        return higher + 1, total

    def _exists(
        self, model: type[Meal] | type[WaterEntry] | type[ActivityEntry], user_id: UUID
    ) -> bool:
        return bool(self.session.scalar(select(model.id).where(model.user_id == user_id).limit(1)))

    def _distinct_days(self, model: type[Meal] | type[ActivityEntry], user_id: UUID) -> int:
        return int(
            self.session.scalar(
                select(func.count(func.distinct(model.record_date))).where(model.user_id == user_id)
            )
            or 0
        )

    def _hydration_days(self, user_id: UUID, target: int) -> int:
        rows = self.session.execute(
            select(WaterEntry.record_date, func.sum(WaterEntry.amount_ml))
            .where(WaterEntry.user_id == user_id)
            .group_by(WaterEntry.record_date)
        )
        return sum(1 for row in rows if int(row[1] or 0) >= target)
