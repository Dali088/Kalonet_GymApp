from datetime import UTC, date, datetime, time
from decimal import Decimal
from typing import Any, Literal, cast
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import (
    ActivityEntry,
    IdempotencyRecord,
    Meal,
    MealItem,
    User,
    UserSettings,
    WaterEntry,
)
from kalonet_backend.repositories import (
    ActivityRepository,
    DashboardRepository,
    IdempotencyReplay,
    IdempotencyRepository,
    MealRepository,
    NutritionTargetRepository,
    StepsRepository,
    WaterRepository,
    request_hash,
)
from kalonet_backend.schemas.tracking import (
    ActivityCreate,
    ActivityListResponse,
    ActivityResponse,
    ActivityTotals,
    ActivityType,
    ActivityUpdate,
    DailyDashboardResponse,
    DailyStepsIncrement,
    DailyStepsResponse,
    DailyStepsUpdate,
    DashboardActivity,
    DashboardMeals,
    DashboardNutrition,
    DashboardSteps,
    DashboardTarget,
    DashboardWater,
    MealCreate,
    MealItemCreate,
    MealItemCreatedResponse,
    MealItemResponse,
    MealItemUpdate,
    MealResponse,
    MealsResponse,
    MealUpdate,
    NutritionTotals,
    NutritionValues,
    WaterCreatedResponse,
    WaterEntryCreate,
    WaterEntryResponse,
    WaterEntryUpdate,
    WaterListResponse,
)
from kalonet_backend.services.gamification import GamificationService


class FutureDateNotAllowedError(Exception):
    """A write targets a future local calendar date."""


class MealNotFoundError(Exception):
    pass


class MealItemNotFoundError(Exception):
    pass


class WaterEntryNotFoundError(Exception):
    pass


class ActivityNotFoundError(Exception):
    pass


class OnboardingRequiredError(Exception):
    pass


class ActiveNutritionTargetNotFoundError(Exception):
    pass


class OperationResult:
    """Service output carrying an HTTP-neutral body and replay metadata."""

    def __init__(self, body: Any, status_code: int = 200, replay: bool = False) -> None:
        self.body = body
        self.status_code = status_code
        self.replay = replay


def _nutrition(values: tuple[object, object, object, object]) -> NutritionTotals:
    return NutritionTotals(
        calories_kcal=Decimal(str(values[0] or 0)),
        protein_g=Decimal(str(values[1] or 0)),
        carbohydrate_g=Decimal(str(values[2] or 0)),
        fat_g=Decimal(str(values[3] or 0)),
    )


def _item_response(item: MealItem) -> MealItemResponse:
    return MealItemResponse(
        id=item.id,
        name=item.name,
        quantity=item.quantity,
        serving_description=item.serving_description,
        nutrition=NutritionValues(
            calories_kcal=item.calories_kcal,
            protein_g=item.protein_g,
            carbohydrate_g=item.carbohydrate_g,
            fat_g=item.fat_g,
        ),
    )


def _meal_response(meal: Meal) -> MealResponse:
    items = [_item_response(item) for item in meal.items]
    totals = NutritionTotals(
        calories_kcal=sum((item.nutrition.calories_kcal for item in items), Decimal(0)),
        protein_g=sum((item.nutrition.protein_g for item in items), Decimal(0)),
        carbohydrate_g=sum((item.nutrition.carbohydrate_g for item in items), Decimal(0)),
        fat_g=sum((item.nutrition.fat_g for item in items), Decimal(0)),
    )
    return MealResponse(
        id=meal.id,
        meal_type=meal.meal_type,  # type: ignore[arg-type]
        name=meal.name,
        recorded_at=meal.recorded_at,
        totals=totals,
        items=items,
    )


def _local_datetime(record_date: date, recorded_time: time, time_zone: str) -> datetime:
    return datetime.combine(record_date, recorded_time, tzinfo=ZoneInfo(time_zone)).astimezone(UTC)


def _local_date(recorded_at: datetime, time_zone: str) -> date:
    aware = recorded_at if recorded_at.tzinfo is not None else recorded_at.replace(tzinfo=UTC)
    return aware.astimezone(ZoneInfo(time_zone)).date()


class TrackingService:
    """Coordinates tracking rules and owns each multi-write transaction."""

    def __init__(self, session: Session, *, now: datetime | None = None) -> None:
        self.session = session
        self.now = now or datetime.now(UTC)
        self.meals = MealRepository(session)
        self.water = WaterRepository(session)
        self.steps = StepsRepository(session)
        self.activities = ActivityRepository(session)
        self.dashboard = DashboardRepository(session)
        self.idempotency = IdempotencyRepository(session)
        self.gamification = GamificationService(session)

    def _settings(self, user_id: UUID) -> UserSettings:
        settings = self.session.scalar(select(UserSettings).where(UserSettings.user_id == user_id))
        return settings or UserSettings(user_id=user_id, time_zone="UTC")

    def _ensure_not_future(self, record_date: date, time_zone: str) -> None:
        if record_date > self.now.astimezone(ZoneInfo(time_zone)).date():
            raise FutureDateNotAllowedError

    def _reservation(
        self, user_id: UUID, key: str | None, route: str, payload: object
    ) -> tuple[IdempotencyRecord | IdempotencyReplay | None, str | None]:
        if key is None:
            return None, None
        if not 1 <= len(key) <= 128:
            raise ValueError("Invalid idempotency key")
        payload_hash = request_hash(payload)
        record = self.idempotency.reserve(
            user_id=user_id, key=key, route_pattern=route, payload_hash=payload_hash
        )
        if isinstance(record, IdempotencyReplay):
            return record, payload_hash
        return record, payload_hash

    def _finish(
        self,
        reservation: IdempotencyRecord | IdempotencyReplay | None,
        body: Any,
        status_code: int,
    ) -> OperationResult:
        body_model = body if hasattr(body, "model_dump") else body
        if isinstance(reservation, IdempotencyRecord):
            self.idempotency.complete(reservation, status_code, body_model.model_dump(mode="json"))
        self.session.commit()
        return OperationResult(body, status_code)

    def _replay(self, reservation: object) -> OperationResult | None:
        if isinstance(reservation, IdempotencyReplay):
            return OperationResult(reservation.body, reservation.status_code, replay=True)
        return None

    def list_meals(self, user_id: UUID, record_date: date) -> MealsResponse:
        meals = self.meals.list_for_date(user_id, record_date)
        responses = [_meal_response(meal) for meal in meals]
        totals = NutritionTotals(
            calories_kcal=sum((meal.totals.calories_kcal for meal in responses), Decimal(0)),
            protein_g=sum((meal.totals.protein_g for meal in responses), Decimal(0)),
            carbohydrate_g=sum((meal.totals.carbohydrate_g for meal in responses), Decimal(0)),
            fat_g=sum((meal.totals.fat_g for meal in responses), Decimal(0)),
        )
        return MealsResponse(record_date=record_date, items=responses, daily_totals=totals)

    def create_meal(self, user_id: UUID, payload: MealCreate, key: str | None) -> OperationResult:
        settings = self._settings(user_id)
        self._ensure_not_future(payload.record_date, settings.time_zone)
        reservation, _ = self._reservation(
            user_id, key, "/api/v1/users/me/meals", payload.model_dump(mode="json")
        )
        replay = self._replay(reservation)
        if replay is not None:
            return replay
        meal = Meal(
            user_id=user_id,
            record_date=payload.record_date,
            meal_type=payload.meal_type,
            name=payload.name,
            recorded_at=_local_datetime(
                payload.record_date, payload.recorded_time, settings.time_zone
            ),
        )
        for index, item in enumerate(payload.items, start=1):
            meal.items.append(self._new_item(item, index))
        self.meals.add(meal)
        self.gamification.evaluate_after_tracking(user_id, payload.record_date)
        return self._finish(reservation, _meal_response(meal), 201)

    @staticmethod
    def _new_item(item: MealItemCreate, display_order: int) -> MealItem:
        return MealItem(
            display_order=display_order,
            name=item.name,
            quantity=item.quantity,
            serving_description=item.serving_description,
            calories_kcal=item.nutrition.calories_kcal,
            protein_g=item.nutrition.protein_g,
            carbohydrate_g=item.nutrition.carbohydrate_g,
            fat_g=item.nutrition.fat_g,
        )

    def get_meal(self, user_id: UUID, meal_id: UUID) -> MealResponse:
        meal = self.meals.get(user_id, meal_id)
        if meal is None:
            raise MealNotFoundError
        return _meal_response(meal)

    def update_meal(self, user_id: UUID, meal_id: UUID, payload: MealUpdate) -> MealResponse:
        meal = self.meals.get(user_id, meal_id)
        if meal is None:
            raise MealNotFoundError
        settings = self._settings(user_id)
        new_date = payload.record_date or meal.record_date
        self._ensure_not_future(new_date, settings.time_zone)
        if payload.meal_type is not None:
            meal.meal_type = payload.meal_type
        if payload.name is not None:
            meal.name = payload.name
        local = meal.recorded_at.astimezone(ZoneInfo(settings.time_zone))
        meal.record_date = new_date
        meal.recorded_at = _local_datetime(
            new_date, payload.recorded_time or local.time(), settings.time_zone
        )
        self.session.flush()
        result = _meal_response(meal)
        self.gamification.evaluate_after_tracking(user_id, new_date)
        self.session.commit()
        return result

    def add_item(
        self, user_id: UUID, meal_id: UUID, payload: MealItemCreate, key: str | None
    ) -> OperationResult:
        meal = self.meals.get(user_id, meal_id)
        if meal is None:
            raise MealNotFoundError
        reservation, _ = self._reservation(
            user_id, key, f"/api/v1/users/me/meals/{meal_id}/items", payload.model_dump(mode="json")
        )
        replay = self._replay(reservation)
        if replay is not None:
            return replay
        item = self._new_item(payload, self.meals.next_display_order(meal_id))
        meal.items.append(item)
        self.session.flush()
        result = MealItemCreatedResponse(item=_item_response(item), meal=_meal_response(meal))
        return self._finish(reservation, result, 201)

    def update_item(
        self, user_id: UUID, meal_id: UUID, item_id: UUID, payload: MealItemUpdate
    ) -> MealItemCreatedResponse:
        item = self.meals.get_item(user_id, meal_id, item_id)
        if item is None:
            raise MealItemNotFoundError
        if payload.name is not None:
            item.name = payload.name
        if payload.quantity is not None:
            item.quantity = payload.quantity
        if payload.serving_description is not None:
            item.serving_description = payload.serving_description
        if payload.nutrition is not None:
            item.calories_kcal = payload.nutrition.calories_kcal
            item.protein_g = payload.nutrition.protein_g
            item.carbohydrate_g = payload.nutrition.carbohydrate_g
            item.fat_g = payload.nutrition.fat_g
        self.session.flush()
        meal = self.meals.get(user_id, meal_id)
        assert meal is not None
        result = MealItemCreatedResponse(item=_item_response(item), meal=_meal_response(meal))
        self.session.commit()
        return result

    def delete_item(self, user_id: UUID, meal_id: UUID, item_id: UUID) -> None:
        item = self.meals.get_item(user_id, meal_id, item_id)
        if item is None:
            raise MealItemNotFoundError
        self.meals.delete_item(item)
        if self.meals.count_items(meal_id) == 0:
            meal = self.meals.get(user_id, meal_id)
            if meal is not None:
                self.meals.delete(meal)
        self.session.commit()

    def delete_meal(self, user_id: UUID, meal_id: UUID) -> None:
        meal = self.meals.get(user_id, meal_id)
        if meal is None:
            raise MealNotFoundError
        self.meals.delete(meal)
        self.session.commit()

    def list_water(self, user_id: UUID, record_date: date) -> WaterListResponse:
        entries = self.water.list_for_date(user_id, record_date)
        return WaterListResponse(
            record_date=record_date,
            items=[self._water_response(entry) for entry in entries],
            total_ml=sum(entry.amount_ml for entry in entries),
            target_ml=None,
        )

    @staticmethod
    def _water_response(entry: WaterEntry) -> WaterEntryResponse:
        return WaterEntryResponse(
            id=entry.id,
            amount_ml=entry.amount_ml,
            recorded_at=entry.recorded_at,
            record_date=entry.record_date,
            created_at=entry.created_at,
        )

    def create_water(
        self, user_id: UUID, payload: WaterEntryCreate, key: str | None
    ) -> OperationResult:
        settings = self._settings(user_id)
        if payload.recorded_at.tzinfo is None:
            raise ValueError("recorded_at must include a timezone")
        recorded_at = payload.recorded_at.astimezone(UTC)
        record_date = _local_date(recorded_at, settings.time_zone)
        self._ensure_not_future(record_date, settings.time_zone)
        reservation, _ = self._reservation(
            user_id, key, "/api/v1/users/me/water-entries", payload.model_dump(mode="json")
        )
        replay = self._replay(reservation)
        if replay is not None:
            return replay
        entry = self.water.add(
            WaterEntry(
                user_id=user_id,
                record_date=record_date,
                amount_ml=payload.amount_ml,
                recorded_at=recorded_at,
            )
        )
        self.gamification.evaluate_after_tracking(user_id, record_date)
        body = WaterCreatedResponse(
            **self._water_response(entry).model_dump(),
            daily_total_ml=self.water.total_for_date(user_id, record_date),
        )
        return self._finish(reservation, body, 201)

    def update_water(
        self, user_id: UUID, entry_id: UUID, payload: WaterEntryUpdate
    ) -> WaterCreatedResponse:
        entry = self.water.get(user_id, entry_id)
        if entry is None:
            raise WaterEntryNotFoundError
        settings = self._settings(user_id)
        if payload.amount_ml is not None:
            entry.amount_ml = payload.amount_ml
        if payload.recorded_at is not None:
            if payload.recorded_at.tzinfo is None:
                raise ValueError("recorded_at must include a timezone")
            entry.recorded_at = payload.recorded_at.astimezone(UTC)
            entry.record_date = _local_date(entry.recorded_at, settings.time_zone)
        self._ensure_not_future(entry.record_date, settings.time_zone)
        self.session.flush()
        body = WaterCreatedResponse(
            **self._water_response(entry).model_dump(),
            daily_total_ml=self.water.total_for_date(user_id, entry.record_date),
        )
        self.gamification.evaluate_after_tracking(user_id, entry.record_date)
        self.session.commit()
        return body

    def delete_water(self, user_id: UUID, entry_id: UUID) -> None:
        entry = self.water.get(user_id, entry_id)
        if entry is None:
            raise WaterEntryNotFoundError
        self.water.delete(entry)
        self.session.commit()

    def get_steps(self, user_id: UUID, record_date: date) -> DailyStepsResponse:
        entry = self.steps.get(user_id, record_date)
        return DailyStepsResponse(
            record_date=record_date,
            step_count=entry.step_count if entry else 0,
            source=cast(Literal["manual"], entry.source) if entry else None,
            target=None,
            updated_at=entry.updated_at if entry else None,
        )

    def set_steps(
        self, user_id: UUID, record_date: date, payload: DailyStepsUpdate
    ) -> DailyStepsResponse:
        settings = self._settings(user_id)
        self._ensure_not_future(record_date, settings.time_zone)
        entry = self.steps.upsert(user_id, record_date, payload.step_count, payload.source)
        self.gamification.evaluate_after_tracking(user_id, record_date)
        body = DailyStepsResponse(
            record_date=record_date,
            step_count=entry.step_count,
            source=cast(Literal["manual"], entry.source),
            target=None,
            updated_at=entry.updated_at,
        )
        self.session.commit()
        return body

    def add_steps(
        self, user_id: UUID, record_date: date, payload: DailyStepsIncrement
    ) -> DailyStepsResponse:
        settings = self._settings(user_id)
        self._ensure_not_future(record_date, settings.time_zone)
        entry = self.steps.increment_atomic(user_id, record_date, payload.increment)
        self.gamification.evaluate_after_tracking(user_id, record_date)
        body = DailyStepsResponse(
            record_date=record_date,
            step_count=entry.step_count,
            source=cast(Literal["manual"], entry.source),
            target=None,
            updated_at=entry.updated_at,
        )
        self.session.commit()
        return body

    def list_activities(self, user_id: UUID, record_date: date) -> ActivityListResponse:
        entries = self.activities.list_for_date(user_id, record_date)
        return ActivityListResponse(
            record_date=record_date,
            items=[self._activity_response(entry) for entry in entries],
            totals=ActivityTotals(
                duration_minutes=sum(entry.duration_minutes for entry in entries),
                estimated_calories_kcal=sum(
                    (entry.estimated_calories_kcal or Decimal(0) for entry in entries), Decimal(0)
                ),
            ),
        )

    @staticmethod
    def _activity_response(entry: ActivityEntry) -> ActivityResponse:
        return ActivityResponse(
            id=entry.id,
            activity_type=cast(ActivityType, entry.activity_type),
            name=entry.name,
            duration_minutes=entry.duration_minutes,
            estimated_calories_kcal=entry.estimated_calories_kcal,
            recorded_at=entry.recorded_at,
        )

    def create_activity(
        self, user_id: UUID, payload: ActivityCreate, key: str | None
    ) -> OperationResult:
        settings = self._settings(user_id)
        if payload.recorded_at.tzinfo is None:
            raise ValueError("recorded_at must include a timezone")
        recorded_at = payload.recorded_at.astimezone(UTC)
        record_date = _local_date(recorded_at, settings.time_zone)
        self._ensure_not_future(record_date, settings.time_zone)
        reservation, _ = self._reservation(
            user_id, key, "/api/v1/users/me/activities", payload.model_dump(mode="json")
        )
        replay = self._replay(reservation)
        if replay is not None:
            return replay
        entry = self.activities.add(
            ActivityEntry(
                user_id=user_id,
                record_date=record_date,
                activity_type=payload.activity_type,
                name=payload.name,
                duration_minutes=payload.duration_minutes,
                estimated_calories_kcal=payload.estimated_calories_kcal,
                recorded_at=recorded_at,
            )
        )
        self.gamification.evaluate_after_tracking(user_id, record_date)
        return self._finish(reservation, self._activity_response(entry), 201)

    def update_activity(
        self, user_id: UUID, activity_id: UUID, payload: ActivityUpdate
    ) -> ActivityResponse:
        entry = self.activities.get(user_id, activity_id)
        if entry is None:
            raise ActivityNotFoundError
        settings = self._settings(user_id)
        if payload.activity_type is not None:
            entry.activity_type = payload.activity_type
        if payload.name is not None:
            entry.name = payload.name
        if payload.duration_minutes is not None:
            entry.duration_minutes = payload.duration_minutes
        if "estimated_calories_kcal" in payload.model_fields_set:
            entry.estimated_calories_kcal = payload.estimated_calories_kcal
        if payload.recorded_at is not None:
            if payload.recorded_at.tzinfo is None:
                raise ValueError("recorded_at must include a timezone")
            entry.recorded_at = payload.recorded_at.astimezone(UTC)
            entry.record_date = _local_date(entry.recorded_at, settings.time_zone)
        self._ensure_not_future(entry.record_date, settings.time_zone)
        self.session.flush()
        body = self._activity_response(entry)
        self.gamification.evaluate_after_tracking(user_id, entry.record_date)
        self.session.commit()
        return body

    def delete_activity(self, user_id: UUID, activity_id: UUID) -> None:
        entry = self.activities.get(user_id, activity_id)
        if entry is None:
            raise ActivityNotFoundError
        self.activities.delete(entry)
        self.session.commit()

    def dashboard_for_date(self, user_id: UUID, record_date: date) -> DailyDashboardResponse:
        settings = self._settings(user_id)
        user = self.session.scalar(select(User).where(User.id == user_id))
        if user is None or user.onboarding_completed_at is None:
            raise OnboardingRequiredError
        target = NutritionTargetRepository(self.session).get_active(user_id)
        if target is None:
            raise ActiveNutritionTargetNotFoundError
        meal_count, item_count, meal_values = self.dashboard.meal_totals(user_id, record_date)
        water_total = self.dashboard.water_total(user_id, record_date)
        steps_total = self.dashboard.steps_total(user_id, record_date)
        activity_count, duration, activity_calories = self.dashboard.activity_totals(
            user_id, record_date
        )
        target_values = DashboardTarget(
            calories_kcal=target.daily_calories,
            protein_g=target.protein_g,
            carbohydrate_g=target.carbohydrate_g,
            fat_g=target.fat_g,
        )
        consumed = DashboardTarget(
            calories_kcal=round(Decimal(str(meal_values[0] or 0))),
            protein_g=round(Decimal(str(meal_values[1] or 0))),
            carbohydrate_g=round(Decimal(str(meal_values[2] or 0))),
            fat_g=round(Decimal(str(meal_values[3] or 0))),
        )
        remaining = DashboardTarget(
            calories_kcal=target_values.calories_kcal - consumed.calories_kcal,
            protein_g=target_values.protein_g - consumed.protein_g,
            carbohydrate_g=target_values.carbohydrate_g - consumed.carbohydrate_g,
            fat_g=target_values.fat_g - consumed.fat_g,
        )
        return DailyDashboardResponse(
            record_date=record_date,
            time_zone=settings.time_zone,
            nutrition=DashboardNutrition(
                target=target_values, consumed=consumed, remaining=remaining
            ),
            meals=DashboardMeals(logged_meal_count=meal_count, logged_item_count=item_count),
            water=DashboardWater(consumed_ml=water_total, target_ml=None),
            steps=DashboardSteps(count=steps_total, target=None),
            activity=DashboardActivity(
                activity_count=activity_count,
                duration_minutes=duration,
                estimated_calories_kcal=Decimal(str(activity_calories or 0)),
            ),
            generated_at=datetime.now(UTC),
        )
