from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.orm import Session, selectinload

from kalonet_backend.models import ActivityEntry, DailyStepRecord, Meal, MealItem, WaterEntry


class DailyStepLimitExceededError(Exception):
    """The requested increment would exceed the per-day safety limit."""


class MealRepository:
    """Ownership-scoped meal and meal-item persistence operations."""

    def list_for_date(self, user_id: UUID, record_date: date) -> list[Meal]:
        statement = (
            select(Meal)
            .where(Meal.user_id == user_id, Meal.record_date == record_date)
            .options(selectinload(Meal.items))
            .order_by(Meal.recorded_at, Meal.id)
        )
        return list(self.session.scalars(statement).unique().all())

    def __init__(self, session: Session) -> None:
        self.session = session

    def get(self, user_id: UUID, meal_id: UUID) -> Meal | None:
        statement = (
            select(Meal)
            .where(Meal.id == meal_id, Meal.user_id == user_id)
            .options(selectinload(Meal.items))
        )
        return self.session.scalars(statement).unique().one_or_none()

    def add(self, meal: Meal) -> Meal:
        self.session.add(meal)
        self.session.flush()
        return meal

    def get_item(self, user_id: UUID, meal_id: UUID, item_id: UUID) -> MealItem | None:
        statement = (
            select(MealItem)
            .join(Meal, Meal.id == MealItem.meal_id)
            .where(MealItem.id == item_id, MealItem.meal_id == meal_id, Meal.user_id == user_id)
        )
        return self.session.scalar(statement)

    def next_display_order(self, meal_id: UUID) -> int:
        current = self.session.scalar(
            select(func.coalesce(func.max(MealItem.display_order), 0)).where(
                MealItem.meal_id == meal_id
            )
        )
        return int(current or 0) + 1

    def delete_item(self, item: MealItem) -> None:
        self.session.delete(item)
        self.session.flush()

    def count_items(self, meal_id: UUID) -> int:
        return int(
            self.session.scalar(
                select(func.count()).select_from(MealItem).where(MealItem.meal_id == meal_id)
            )
            or 0
        )

    def delete(self, meal: Meal) -> None:
        self.session.delete(meal)
        self.session.flush()


class WaterRepository:
    """Ownership-scoped water persistence and daily totals."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_date(self, user_id: UUID, record_date: date) -> list[WaterEntry]:
        return list(
            self.session.scalars(
                select(WaterEntry)
                .where(WaterEntry.user_id == user_id, WaterEntry.record_date == record_date)
                .order_by(WaterEntry.recorded_at, WaterEntry.id)
            ).all()
        )

    def total_for_date(self, user_id: UUID, record_date: date) -> int:
        return int(
            self.session.scalar(
                select(func.coalesce(func.sum(WaterEntry.amount_ml), 0)).where(
                    WaterEntry.user_id == user_id, WaterEntry.record_date == record_date
                )
            )
            or 0
        )

    def get(self, user_id: UUID, entry_id: UUID) -> WaterEntry | None:
        return self.session.scalar(
            select(WaterEntry).where(WaterEntry.user_id == user_id, WaterEntry.id == entry_id)
        )

    def add(self, entry: WaterEntry) -> WaterEntry:
        self.session.add(entry)
        self.session.flush()
        return entry

    def delete(self, entry: WaterEntry) -> None:
        self.session.delete(entry)
        self.session.flush()


class StepsRepository:
    """One-row-per-user/date daily steps persistence."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def get(self, user_id: UUID, record_date: date) -> DailyStepRecord | None:
        return self.session.scalar(
            select(DailyStepRecord).where(
                DailyStepRecord.user_id == user_id, DailyStepRecord.record_date == record_date
            )
        )

    def upsert(
        self, user_id: UUID, record_date: date, step_count: int, source: str
    ) -> DailyStepRecord:
        existing = self.get(user_id, record_date)
        if existing is None:
            existing = DailyStepRecord(
                user_id=user_id, record_date=record_date, step_count=step_count, source=source
            )
            self.session.add(existing)
        else:
            existing.step_count = step_count
            existing.source = source
        self.session.flush()
        return existing

    def increment_atomic(self, user_id: UUID, record_date: date, increment: int) -> DailyStepRecord:
        """Atomically add steps without a read-modify-write race."""

        statement = (
            postgresql_insert(DailyStepRecord)
            .values(
                id=uuid4(),
                user_id=user_id,
                record_date=record_date,
                step_count=increment,
                source="manual",
            )
            .on_conflict_do_update(
                index_elements=[DailyStepRecord.user_id, DailyStepRecord.record_date],
                set_={
                    "step_count": DailyStepRecord.step_count + increment,
                    "updated_at": func.now(),
                },
                where=DailyStepRecord.step_count + increment <= 200000,
            )
            .returning(DailyStepRecord.id)
        )
        record_id = self.session.execute(statement).scalar_one_or_none()
        if record_id is None:
            raise DailyStepLimitExceededError
        self.session.flush()
        record = self.session.scalar(select(DailyStepRecord).where(DailyStepRecord.id == record_id))
        if record is None:  # pragma: no cover - the RETURNING row is authoritative
            raise DailyStepLimitExceededError
        return record


class ActivityRepository:
    """Ownership-scoped activity persistence and aggregate queries."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_date(self, user_id: UUID, record_date: date) -> list[ActivityEntry]:
        return list(
            self.session.scalars(
                select(ActivityEntry)
                .where(ActivityEntry.user_id == user_id, ActivityEntry.record_date == record_date)
                .order_by(ActivityEntry.recorded_at, ActivityEntry.id)
            ).all()
        )

    def totals_for_date(self, user_id: UUID, record_date: date) -> tuple[int, object]:
        row = self.session.execute(
            select(
                func.count(ActivityEntry.id),
                func.coalesce(func.sum(ActivityEntry.duration_minutes), 0),
                func.coalesce(func.sum(ActivityEntry.estimated_calories_kcal), 0),
            ).where(ActivityEntry.user_id == user_id, ActivityEntry.record_date == record_date)
        ).one()
        return int(row[0]), (row[1], row[2])

    def get(self, user_id: UUID, activity_id: UUID) -> ActivityEntry | None:
        return self.session.scalar(
            select(ActivityEntry).where(
                ActivityEntry.user_id == user_id, ActivityEntry.id == activity_id
            )
        )

    def add(self, entry: ActivityEntry) -> ActivityEntry:
        self.session.add(entry)
        self.session.flush()
        return entry

    def delete(self, entry: ActivityEntry) -> None:
        self.session.delete(entry)
        self.session.flush()


class DashboardRepository:
    """Small aggregate queries used to assemble the dashboard read model."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def meal_totals(
        self, user_id: UUID, record_date: date
    ) -> tuple[int, int, tuple[object, object, object, object]]:
        row = self.session.execute(
            select(
                func.count(func.distinct(Meal.id)),
                func.count(MealItem.id),
                func.coalesce(func.sum(MealItem.calories_kcal), 0),
                func.coalesce(func.sum(MealItem.protein_g), 0),
                func.coalesce(func.sum(MealItem.carbohydrate_g), 0),
                func.coalesce(func.sum(MealItem.fat_g), 0),
            )
            .select_from(Meal)
            .outerjoin(MealItem, MealItem.meal_id == Meal.id)
            .where(Meal.user_id == user_id, Meal.record_date == record_date)
        ).one()
        return int(row[0]), int(row[1]), (row[2], row[3], row[4], row[5])

    def water_total(self, user_id: UUID, record_date: date) -> int:
        return int(
            self.session.scalar(
                select(func.coalesce(func.sum(WaterEntry.amount_ml), 0)).where(
                    WaterEntry.user_id == user_id, WaterEntry.record_date == record_date
                )
            )
            or 0
        )

    def steps_total(self, user_id: UUID, record_date: date) -> int:
        return int(
            self.session.scalar(
                select(func.coalesce(DailyStepRecord.step_count, 0)).where(
                    DailyStepRecord.user_id == user_id, DailyStepRecord.record_date == record_date
                )
            )
            or 0
        )

    def activity_totals(self, user_id: UUID, record_date: date) -> tuple[int, int, object]:
        row = self.session.execute(
            select(
                func.count(ActivityEntry.id),
                func.coalesce(func.sum(ActivityEntry.duration_minutes), 0),
                func.coalesce(func.sum(ActivityEntry.estimated_calories_kcal), 0),
            ).where(ActivityEntry.user_id == user_id, ActivityEntry.record_date == record_date)
        ).one()
        return int(row[0]), int(row[1]), row[2]
