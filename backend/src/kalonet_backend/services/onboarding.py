from collections.abc import Callable
from datetime import UTC, date, datetime, time
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from kalonet_backend.models import NutritionTarget, User, UserProfile
from kalonet_backend.repositories import (
    NutritionTargetRepository,
    PersonalizationRepository,
    UserRepository,
)
from kalonet_backend.schemas.personalization import (
    MealScheduleInput,
    Measurements,
    NutritionRecalculationRequest,
    OnboardingDraftPatch,
)
from kalonet_backend.services.nutrition import (
    NutritionCalculationInputs,
    NutritionCalculationResult,
    NutritionCalculationService,
    UnsupportedNutritionProfileError,
)


class UserNotFoundError(ValueError):
    """Raised when a token refers to an account that no longer exists."""


class OnboardingAlreadyCompletedError(ValueError):
    """Raised when a draft or completion operation targets a completed account."""


class OnboardingInputsIncompleteError(ValueError):
    """Raised when required onboarding source data is missing."""


class TargetNotAcceptedError(ValueError):
    """Raised when completion lacks explicit target acceptance."""


class InvalidPreferenceError(ValueError):
    """Raised for duplicate, unknown, or inactive preference codes."""


class InvalidMealScheduleError(ValueError):
    """Raised when the complete schedule set is invalid."""


class ProfileNotCompletedError(ValueError):
    """Raised when a post-onboarding profile resource is requested too early."""


class CalculationInputsUnchangedError(ValueError):
    """Raised when recalculation would create a meaningless duplicate snapshot."""


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _parse_time(value: str) -> time:
    hour, minute = (int(part) for part in value.split(":"))
    return time(hour=hour, minute=minute)


def _schedule_values(items: list[MealScheduleInput]) -> list[tuple[str, time, int]]:
    if len(items) > 20:
        raise InvalidMealScheduleError
    meal_types = [item.meal_type for item in items]
    display_orders = [item.display_order for item in items]
    if len(set(meal_types)) != len(meal_types) or len(set(display_orders)) != len(display_orders):
        raise InvalidMealScheduleError
    try:
        return [
            (item.meal_type, _parse_time(item.preferred_time), item.display_order) for item in items
        ]
    except (TypeError, ValueError) as error:
        raise InvalidMealScheduleError from error


def _calculation_inputs(
    profile: UserProfile | None,
    *,
    goal: str | None = None,
    measurements: Measurements | None = None,
    activity_level: str | None = None,
) -> NutritionCalculationInputs:
    if profile is None:
        raise OnboardingInputsIncompleteError

    resolved_goal = goal if goal is not None else profile.goal
    resolved_dob = measurements.date_of_birth if measurements is not None else profile.date_of_birth
    resolved_sex = (
        measurements.sex_for_formula if measurements is not None else profile.sex_for_formula
    )
    resolved_height = measurements.height_cm if measurements is not None else profile.height_cm
    resolved_weight = measurements.weight_kg if measurements is not None else profile.weight_kg
    resolved_activity = activity_level if activity_level is not None else profile.activity_level

    if None in (
        resolved_goal,
        resolved_dob,
        resolved_sex,
        resolved_height,
        resolved_weight,
        resolved_activity,
    ):
        raise OnboardingInputsIncompleteError

    assert resolved_dob is not None
    assert resolved_sex is not None
    assert resolved_height is not None
    assert resolved_weight is not None

    return NutritionCalculationInputs(
        goal=str(resolved_goal),
        date_of_birth=resolved_dob,
        sex_for_formula=str(resolved_sex),
        height_cm=Decimal(resolved_height),
        weight_kg=Decimal(resolved_weight),
        activity_level=str(resolved_activity),
    )


class OnboardingService:
    """Coordinate resumable onboarding and target activation transactions."""

    def __init__(
        self,
        session: Session,
        *,
        clock: Callable[[], datetime] = _utc_now,
        calculation_service: NutritionCalculationService | None = None,
    ) -> None:
        self._session = session
        self._clock = clock
        self._users = UserRepository(session)
        self._personalization = PersonalizationRepository(session)
        self._targets = NutritionTargetRepository(session)
        self._calculator = calculation_service or NutritionCalculationService()

    def get_user(self, user_id: UUID) -> User:
        user = self._users.get_by_id(user_id)
        if user is None:
            raise UserNotFoundError
        return user

    def current_time(self) -> datetime:
        """Return the service clock used for deterministic API timestamps."""
        return self._clock()

    def has_active_target(self, user_id: UUID) -> bool:
        return self._targets.get_active(user_id) is not None

    def get_state(self, user_id: UUID) -> tuple[User, UserProfile | None, list[str], list[Any]]:
        user = self.get_user(user_id)
        profile = self._personalization.get_profile(user_id)
        preferences = self._personalization.list_preference_codes(user_id)
        schedule = self._personalization.list_schedule(user_id)
        return user, profile, preferences, schedule

    def save_draft(self, user_id: UUID, payload: OnboardingDraftPatch) -> None:
        try:
            user = self._users.get_by_id_for_update(user_id)
            if user is None:
                raise UserNotFoundError
            if user.onboarding_completed_at is not None:
                raise OnboardingAlreadyCompletedError

            profile = self._personalization.get_or_create_profile(user_id)
            values: dict[str, object] = {}
            if payload.goal is not None:
                values["goal"] = payload.goal
            if payload.measurements is not None:
                values.update(
                    {
                        "date_of_birth": payload.measurements.date_of_birth,
                        "sex_for_formula": payload.measurements.sex_for_formula,
                        "height_cm": payload.measurements.height_cm,
                        "weight_kg": payload.measurements.weight_kg,
                    }
                )
            if payload.activity_level is not None:
                values["activity_level"] = payload.activity_level
            self._personalization.update_profile(profile, **values)

            if payload.dietary_preferences is not None:
                self._replace_preferences(user_id, payload.dietary_preferences)
            if payload.meal_schedule is not None:
                self._personalization.replace_schedule(
                    user_id,
                    _schedule_values(payload.meal_schedule),
                )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise

    def preview(
        self, user_id: UUID
    ) -> tuple[NutritionCalculationInputs, NutritionCalculationResult, datetime]:
        user, profile, _, _ = self.get_state(user_id)
        if user.onboarding_completed_at is not None:
            raise OnboardingAlreadyCompletedError
        now = self._clock()
        inputs = _calculation_inputs(profile)
        return inputs, self._calculate(inputs, now.date()), now

    def complete(self, user_id: UUID, *, accepted_target: bool) -> NutritionTarget:
        if not accepted_target:
            raise TargetNotAcceptedError
        now = self._clock()
        try:
            user = self._users.get_by_id_for_update(user_id)
            if user is None:
                raise UserNotFoundError
            if user.onboarding_completed_at is not None:
                raise OnboardingAlreadyCompletedError
            profile = self._personalization.get_profile(user_id, for_update=True)
            _, _, _, schedule = self.get_state(user_id)
            if profile is None or not schedule:
                raise OnboardingInputsIncompleteError
            inputs = _calculation_inputs(profile)
            calculation = self._calculate(inputs, now.date())
            target = _create_target(
                targets=self._targets,
                user_id=user_id,
                inputs=inputs,
                result=calculation,
                effective_from=now.date(),
            )
            user.onboarding_completed_at = now
            self._session.flush()
            self._session.commit()
            return target
        except Exception:
            self._session.rollback()
            raise

    def current_target(self, user_id: UUID) -> NutritionTarget:
        target = self._targets.get_active(user_id)
        if target is None:
            raise OnboardingInputsIncompleteError
        return target

    def replace_preferences(self, user_id: UUID, codes: list[str]) -> list[str]:
        try:
            self.get_user(user_id)
            self._replace_preferences(user_id, codes)
            self._session.commit()
            return self._personalization.list_preference_codes(user_id)
        except Exception:
            self._session.rollback()
            raise

    def replace_schedule(self, user_id: UUID, items: list[MealScheduleInput]) -> list[Any]:
        try:
            self.get_user(user_id)
            rows = self._personalization.replace_schedule(user_id, _schedule_values(items))
            self._session.commit()
            return rows
        except Exception:
            self._session.rollback()
            raise

    def _replace_preferences(self, user_id: UUID, codes: list[str]) -> None:
        if len(set(codes)) != len(codes):
            raise InvalidPreferenceError
        definitions = self._personalization.get_active_preferences(codes)
        if len(definitions) != len(codes):
            raise InvalidPreferenceError
        self._personalization.replace_preferences(
            user_id,
            [definition.id for definition in definitions],
        )

    def _calculate(
        self,
        inputs: NutritionCalculationInputs,
        as_of: date,
    ) -> NutritionCalculationResult:
        try:
            return self._calculator.calculate(inputs, as_of=as_of)
        except UnsupportedNutritionProfileError:
            raise


class ProfileService:
    """Coordinate post-onboarding profile and immutable target recalculation."""

    def __init__(
        self,
        session: Session,
        *,
        clock: Callable[[], datetime] = _utc_now,
        calculation_service: NutritionCalculationService | None = None,
    ) -> None:
        self._session = session
        self._clock = clock
        self._users = UserRepository(session)
        self._personalization = PersonalizationRepository(session)
        self._targets = NutritionTargetRepository(session)
        self._calculator = calculation_service or NutritionCalculationService()

    def get_profile(
        self, user_id: UUID
    ) -> tuple[User, UserProfile, NutritionTarget, list[str], list[Any]]:
        user = self._users.get_by_id(user_id)
        profile = self._personalization.get_profile(user_id)
        target = self._targets.get_active(user_id)
        if user is None:
            raise UserNotFoundError
        if user.onboarding_completed_at is None or profile is None or target is None:
            raise ProfileNotCompletedError
        return (
            user,
            profile,
            target,
            self._personalization.list_preference_codes(user_id),
            self._personalization.list_schedule(user_id),
        )

    def recalculate(
        self, user_id: UUID, payload: NutritionRecalculationRequest
    ) -> tuple[NutritionTarget, NutritionTarget]:
        now = self._clock()
        try:
            user = self._users.get_by_id_for_update(user_id)
            if user is None:
                raise UserNotFoundError
            profile = self._personalization.get_profile(user_id, for_update=True)
            previous = self._targets.get_active(user_id, for_update=True)
            if user.onboarding_completed_at is None or profile is None or previous is None:
                raise ProfileNotCompletedError

            if (
                profile.goal == payload.goal
                and profile.date_of_birth == payload.date_of_birth
                and profile.sex_for_formula == payload.formula_sex
                and profile.height_cm == payload.height_cm
                and profile.weight_kg == payload.weight_kg
                and profile.activity_level == payload.activity_level
            ):
                raise CalculationInputsUnchangedError

            inputs = NutritionCalculationInputs(
                goal=payload.goal,
                date_of_birth=payload.date_of_birth,
                sex_for_formula=payload.formula_sex,
                height_cm=payload.height_cm,
                weight_kg=payload.weight_kg,
                activity_level=payload.activity_level,
            )
            calculation = self._calculator.calculate(inputs, as_of=now.date())
            self._personalization.update_profile(
                profile,
                goal=payload.goal,
                date_of_birth=payload.date_of_birth,
                sex_for_formula=payload.formula_sex,
                height_cm=payload.height_cm,
                weight_kg=payload.weight_kg,
                activity_level=payload.activity_level,
            )
            self._targets.deactivate(previous, deactivated_at=now)
            replacement = _create_target(
                targets=self._targets,
                user_id=user_id,
                inputs=inputs,
                result=calculation,
                effective_from=now.date(),
            )
            self._session.commit()
            return previous, replacement
        except Exception:
            self._session.rollback()
            raise


def _create_target(
    *,
    targets: NutritionTargetRepository,
    user_id: UUID,
    inputs: NutritionCalculationInputs,
    result: NutritionCalculationResult,
    effective_from: date,
) -> NutritionTarget:
    return targets.create(
        user_id=user_id,
        goal=inputs.goal,
        sex_for_formula=inputs.sex_for_formula,
        age_years=result.age_years,
        height_cm=inputs.height_cm,
        weight_kg=inputs.weight_kg,
        activity_level=inputs.activity_level,
        activity_multiplier=result.activity_multiplier,
        bmr_kcal=result.bmr_kcal,
        tdee_kcal=result.tdee_kcal,
        goal_adjustment_kcal=result.goal_adjustment_kcal,
        daily_calories=result.daily_calories,
        protein_g=result.protein_g,
        carbohydrate_g=result.carbohydrate_g,
        fat_g=result.fat_g,
        rule_version=result.rule_version,
        effective_from=effective_from,
    )
