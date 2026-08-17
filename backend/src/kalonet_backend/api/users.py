from datetime import UTC, datetime
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from kalonet_backend.api.dependencies import get_current_access_token_claims
from kalonet_backend.api.errors import build_error_response
from kalonet_backend.api.rate_limit import SlidingWindowRateLimiter, retry_after_headers
from kalonet_backend.core.security import AccessTokenClaims
from kalonet_backend.db.session import get_db_session
from kalonet_backend.models import NutritionTarget, UserSettings
from kalonet_backend.schemas.personalization import (
    AccountDeletionRequest,
    ActivityLevel,
    CalculationSummary,
    CurrentNutritionTargetResponse,
    Goal,
    MealScheduleInput,
    MealScheduleReplaceRequest,
    MealScheduleResponse,
    MealType,
    Measurements,
    MeasurementSystem,
    NutritionPreviewResponse,
    NutritionRecalculationRequest,
    OnboardingCompletionRequest,
    OnboardingCompletionResponse,
    OnboardingDraftPatch,
    OnboardingStateResponse,
    OnboardingTargetResponse,
    PreferencesReplaceRequest,
    PreferencesResponse,
    PreviewInputs,
    ProfileCalculationInputs,
    ProfileResponse,
    ProfileTargetResponse,
    ProfileUserResponse,
    RecalculationInputs,
    RecalculationResponse,
    SettingsPatchRequest,
    SettingsResponse,
    SexForFormula,
    ThemePreference,
)
from kalonet_backend.services import (
    AccountDeletionService,
    CalculationInputsUnchangedError,
    CurrentPasswordIncorrectError,
    InvalidMealScheduleError,
    InvalidPreferenceError,
    InvalidTimeZoneError,
    NutritionCalculationInputs,
    OnboardingAlreadyCompletedError,
    OnboardingInputsIncompleteError,
    OnboardingService,
    ProfileNotCompletedError,
    ProfileService,
    SettingsService,
    TargetNotAcceptedError,
    UnsupportedNutritionProfileError,
    UserNotFoundError,
)
from kalonet_backend.services.nutrition import NutritionCalculationResult

router = APIRouter(prefix="/api/v1/users/me", tags=["Users"])


def get_onboarding_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> OnboardingService:
    return OnboardingService(session)


def get_profile_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> ProfileService:
    return ProfileService(session)


def get_account_deletion_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> AccountDeletionService:
    return AccountDeletionService(session)


def get_settings_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> SettingsService:
    return SettingsService(session)


def get_account_deletion_rate_limiter(request: Request) -> SlidingWindowRateLimiter:
    return cast(SlidingWindowRateLimiter, request.app.state.account_deletion_rate_limiter)


def _invalid_user_response(request: Request) -> JSONResponse:
    return build_error_response(
        request=request,
        status_code=status.HTTP_401_UNAUTHORIZED,
        code="invalid_access_token",
        message="The access token is missing or invalid.",
    )


def _onboarding_state(
    service: OnboardingService,
    user_id: UUID,
) -> OnboardingStateResponse:
    user, profile, preferences, schedule = service.get_state(user_id)
    target_exists = service.has_active_target(user_id)
    measurements = None
    if profile is not None and all(
        value is not None
        for value in (
            profile.date_of_birth,
            profile.sex_for_formula,
            profile.height_cm,
            profile.weight_kg,
        )
    ):
        assert profile.date_of_birth is not None
        assert profile.sex_for_formula is not None
        assert profile.height_cm is not None
        assert profile.weight_kg is not None
        measurements = Measurements(
            date_of_birth=profile.date_of_birth,
            sex_for_formula=cast(SexForFormula, profile.sex_for_formula),
            height_cm=profile.height_cm,
            weight_kg=profile.weight_kg,
        )
    missing_fields: list[str] = []
    if profile is None or profile.goal is None:
        missing_fields.append("goal")
    if profile is None or profile.date_of_birth is None:
        missing_fields.append("date_of_birth")
    if profile is None or profile.sex_for_formula is None:
        missing_fields.append("formula_sex")
    if profile is None or profile.height_cm is None:
        missing_fields.append("height_cm")
    if profile is None or profile.weight_kg is None:
        missing_fields.append("weight_kg")
    if profile is None or profile.activity_level is None:
        missing_fields.append("activity_level")
    if not schedule:
        missing_fields.append("meal_schedule")
    if user.onboarding_completed_at is not None:
        missing_fields = []
    updated_candidates = [user.updated_at]
    if profile is not None:
        updated_candidates.append(profile.updated_at)
    if schedule:
        updated_candidates.extend(item.updated_at for item in schedule)
    updated_at = max(updated_candidates)
    return OnboardingStateResponse(
        status=(
            "completed"
            if user.onboarding_completed_at is not None
            else "in_progress"
            if profile is not None or preferences or schedule
            else "not_started"
        ),
        goal=cast(Goal, profile.goal) if profile is not None and profile.goal else None,
        measurements=measurements,
        activity_level=(
            cast(ActivityLevel, profile.activity_level)
            if profile is not None and profile.activity_level
            else None
        ),
        dietary_preferences=preferences,
        meal_schedule=[
            MealScheduleInput(
                meal_type=cast(MealType, item.meal_type),
                preferred_time=item.preferred_time.strftime("%H:%M"),
                display_order=item.display_order,
            )
            for item in schedule
        ],
        missing_fields=missing_fields,
        nutrition_target_status="active" if target_exists else "not_calculated",
        updated_at=updated_at,
    )


def _target_response(
    target: NutritionTarget,
    *,
    onboarding: bool,
) -> OnboardingTargetResponse | ProfileTargetResponse:
    if onboarding:
        return OnboardingTargetResponse(
            id=str(target.id),
            calculation_version=target.rule_version,
            calories_kcal=target.daily_calories,
            protein_g=target.protein_g,
            carbohydrate_g=target.carbohydrate_g,
            fat_g=target.fat_g,
            effective_from=target.effective_from,
            is_active=target.deactivated_at is None,
        )
    return ProfileTargetResponse(
        id=str(target.id),
        daily_calories=target.daily_calories,
        protein_g=target.protein_g,
        carbohydrate_g=target.carbohydrate_g,
        fat_g=target.fat_g,
        effective_from=target.effective_from,
        rule_version=target.rule_version,
        is_active=target.deactivated_at is None,
    )


def _preview_response(
    inputs: NutritionCalculationInputs,
    result: NutritionCalculationResult,
    calculated_at: datetime,
) -> NutritionPreviewResponse:
    return NutritionPreviewResponse(
        calculation_version=result.rule_version,
        inputs=PreviewInputs(
            goal=cast(Goal, inputs.goal),
            age_years=result.age_years,
            sex_for_formula=cast(SexForFormula, inputs.sex_for_formula),
            height_cm=inputs.height_cm,
            weight_kg=inputs.weight_kg,
            activity_level=cast(ActivityLevel, inputs.activity_level),
        ),
        calculation=CalculationSummary(
            bmr_kcal=round(result.bmr_kcal),
            tdee_kcal=round(result.tdee_kcal),
            goal_adjustment_kcal=result.goal_adjustment_kcal,
        ),
        target=OnboardingTargetResponse(
            id="preview",
            calculation_version=result.rule_version,
            calories_kcal=result.daily_calories,
            protein_g=result.protein_g,
            carbohydrate_g=result.carbohydrate_g,
            fat_g=result.fat_g,
            effective_from=calculated_at.date(),
            is_active=False,
        ),
        warnings=list(result.warnings),
        calculated_at=calculated_at,
    )


@router.get("/onboarding", response_model=OnboardingStateResponse)
def get_onboarding_state(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> OnboardingStateResponse | JSONResponse:
    try:
        return _onboarding_state(service, claims.user_id)
    except UserNotFoundError:
        return _invalid_user_response(request)


@router.patch("/onboarding", response_model=OnboardingStateResponse)
def save_onboarding_draft(
    payload: OnboardingDraftPatch,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> OnboardingStateResponse | JSONResponse:
    try:
        service.save_draft(claims.user_id, payload)
        return _onboarding_state(service, claims.user_id)
    except UserNotFoundError:
        return _invalid_user_response(request)
    except OnboardingAlreadyCompletedError:
        return build_error_response(
            request=request,
            status_code=409,
            code="onboarding_already_completed",
            message="Completed onboarding must be changed through the profile workflow.",
        )
    except (InvalidPreferenceError, InvalidMealScheduleError):
        return build_error_response(
            request=request,
            status_code=422,
            code="validation_error",
            message="Onboarding data is invalid.",
        )


@router.post("/nutrition-target-previews", response_model=NutritionPreviewResponse)
def preview_nutrition_target(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> NutritionPreviewResponse | JSONResponse:
    try:
        inputs, result, calculated_at = service.preview(claims.user_id)
        return _preview_response(inputs, result, calculated_at)
    except UserNotFoundError:
        return _invalid_user_response(request)
    except OnboardingAlreadyCompletedError:
        return build_error_response(
            request=request,
            status_code=409,
            code="onboarding_already_completed",
            message="Completed users use profile recalculation.",
        )
    except OnboardingInputsIncompleteError:
        return build_error_response(
            request=request,
            status_code=400,
            code="onboarding_inputs_incomplete",
            message="Required onboarding inputs are incomplete.",
        )
    except UnsupportedNutritionProfileError:
        return build_error_response(
            request=request,
            status_code=400,
            code="nutrition_calculation_not_supported",
            message="This profile is outside the supported nutrition policy.",
        )


@router.post(
    "/onboarding-completions", response_model=OnboardingCompletionResponse, status_code=201
)
def complete_onboarding(
    payload: OnboardingCompletionRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> OnboardingCompletionResponse | JSONResponse:
    try:
        target = service.complete(claims.user_id, accepted_target=payload.accepted_target)
        return OnboardingCompletionResponse(
            onboarding_completed=True,
            completed_at=service.get_user(claims.user_id).onboarding_completed_at,  # type: ignore[arg-type]
            nutrition_target=cast(
                OnboardingTargetResponse,
                _target_response(target, onboarding=True),
            ),
        )
    except UserNotFoundError:
        return _invalid_user_response(request)
    except TargetNotAcceptedError:
        return build_error_response(
            request=request,
            status_code=400,
            code="target_not_accepted",
            message="The nutrition target must be explicitly accepted.",
        )
    except OnboardingAlreadyCompletedError:
        return build_error_response(
            request=request,
            status_code=409,
            code="onboarding_already_completed",
            message="Onboarding has already been completed.",
        )
    except OnboardingInputsIncompleteError:
        return build_error_response(
            request=request,
            status_code=400,
            code="onboarding_inputs_incomplete",
            message="Required onboarding inputs are incomplete.",
        )
    except UnsupportedNutritionProfileError:
        return build_error_response(
            request=request,
            status_code=400,
            code="nutrition_calculation_not_supported",
            message="This profile is outside the supported nutrition policy.",
        )


@router.get("/nutrition-targets/current", response_model=CurrentNutritionTargetResponse)
def get_current_nutrition_target(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> CurrentNutritionTargetResponse | JSONResponse:
    try:
        target = service.current_target(claims.user_id)
        return CurrentNutritionTargetResponse(
            id=str(target.id),
            calculation_version=target.rule_version,
            calories_kcal=target.daily_calories,
            protein_g=target.protein_g,
            carbohydrate_g=target.carbohydrate_g,
            fat_g=target.fat_g,
            effective_from=target.effective_from,
            is_active=True,
            created_at=target.created_at,
        )
    except OnboardingInputsIncompleteError:
        return build_error_response(
            request=request,
            status_code=404,
            code="active_nutrition_target_not_found",
            message="No active nutrition target exists.",
        )


@router.get("/profile", response_model=ProfileResponse)
def get_profile(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[ProfileService, Depends(get_profile_service)],
) -> ProfileResponse | JSONResponse:
    try:
        user, profile, target, preferences, schedule = service.get_profile(claims.user_id)
        assert profile.date_of_birth is not None
        assert profile.height_cm is not None
        assert profile.weight_kg is not None
        assert profile.goal is not None
        assert profile.sex_for_formula is not None
        assert profile.activity_level is not None
        return ProfileResponse(
            user=ProfileUserResponse(id=str(user.id), email=user.email, onboarding_completed=True),
            calculation_inputs=ProfileCalculationInputs(
                goal=cast(Goal, profile.goal),
                date_of_birth=profile.date_of_birth,
                formula_sex=cast(SexForFormula, profile.sex_for_formula),
                height_cm=profile.height_cm,
                weight_kg=profile.weight_kg,
                activity_level=cast(ActivityLevel, profile.activity_level),
            ),
            current_nutrition_target=cast(
                ProfileTargetResponse,
                _target_response(target, onboarding=False),
            ),
            dietary_preferences=preferences,
            meal_schedule=[
                MealScheduleInput(
                    meal_type=cast(MealType, item.meal_type),
                    preferred_time=item.preferred_time.strftime("%H:%M"),
                    display_order=item.display_order,
                )
                for item in schedule
            ],
        )
    except (UserNotFoundError, ProfileNotCompletedError):
        return build_error_response(
            request=request,
            status_code=403,
            code="onboarding_required",
            message="Complete onboarding before accessing the profile.",
        )


@router.post(
    "/nutrition-target-recalculations", response_model=RecalculationResponse, status_code=201
)
def recalculate_target(
    payload: NutritionRecalculationRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[ProfileService, Depends(get_profile_service)],
) -> RecalculationResponse | JSONResponse:
    try:
        previous, replacement = service.recalculate(claims.user_id, payload)
        return RecalculationResponse(
            calculation_inputs=RecalculationInputs(
                goal=payload.goal,
                height_cm=payload.height_cm,
                weight_kg=payload.weight_kg,
                activity_level=payload.activity_level,
            ),
            nutrition_target=cast(
                ProfileTargetResponse,
                _target_response(replacement, onboarding=False),
            ),
            previous_target_id=str(previous.id),
        )
    except (UserNotFoundError, ProfileNotCompletedError):
        return build_error_response(
            request=request,
            status_code=403,
            code="onboarding_required",
            message="Complete onboarding before recalculating a target.",
        )
    except CalculationInputsUnchangedError:
        return build_error_response(
            request=request,
            status_code=409,
            code="calculation_inputs_unchanged",
            message="The submitted calculation inputs are unchanged.",
        )
    except UnsupportedNutritionProfileError:
        return build_error_response(
            request=request,
            status_code=422,
            code="unsupported_nutrition_profile",
            message="This profile is outside the supported nutrition policy.",
        )


@router.put("/dietary-preferences", response_model=PreferencesResponse)
def replace_dietary_preferences(
    payload: PreferencesReplaceRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> PreferencesResponse | JSONResponse:
    try:
        preferences = service.replace_preferences(claims.user_id, payload.preferences)
        return PreferencesResponse(preferences=preferences, updated_at=service.current_time())
    except (UserNotFoundError, InvalidPreferenceError):
        return build_error_response(
            request=request,
            status_code=422,
            code="validation_error",
            message="One or more dietary preferences are invalid.",
        )


@router.put("/meal-schedule", response_model=MealScheduleResponse)
def replace_meal_schedule(
    payload: MealScheduleReplaceRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[OnboardingService, Depends(get_onboarding_service)],
) -> MealScheduleResponse | JSONResponse:
    try:
        rows = service.replace_schedule(claims.user_id, payload.items)
        return MealScheduleResponse(
            items=[
                MealScheduleInput(
                    meal_type=cast(MealType, row.meal_type),
                    preferred_time=row.preferred_time.strftime("%H:%M"),
                    display_order=row.display_order,
                )
                for row in rows
            ],
            updated_at=datetime.now(UTC),
        )
    except (UserNotFoundError, InvalidMealScheduleError):
        return build_error_response(
            request=request,
            status_code=422,
            code="validation_error",
            message="The meal schedule is invalid.",
        )


@router.get("/settings", response_model=SettingsResponse)
def get_settings(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[SettingsService, Depends(get_settings_service)],
) -> SettingsResponse | JSONResponse:
    try:
        settings = service.get(claims.user_id)
    except UserNotFoundError:
        return _invalid_user_response(request)
    return _settings_response(settings)


@router.patch("/settings", response_model=SettingsResponse)
def update_settings(
    payload: SettingsPatchRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[SettingsService, Depends(get_settings_service)],
) -> SettingsResponse | JSONResponse:
    try:
        settings = service.update(
            claims.user_id,
            measurement_system=payload.measurement_system,
            time_zone=payload.time_zone,
            theme_preference=payload.theme_preference,
        )
    except UserNotFoundError:
        return _invalid_user_response(request)
    except InvalidTimeZoneError:
        return build_error_response(
            request=request,
            status_code=422,
            code="validation_error",
            message="time_zone must be a valid IANA time zone.",
        )
    return _settings_response(settings)


def _settings_response(settings: UserSettings) -> SettingsResponse:
    return SettingsResponse(
        measurement_system=cast(MeasurementSystem, settings.measurement_system),
        time_zone=settings.time_zone,
        theme_preference=cast(ThemePreference, settings.theme_preference),
    )


@router.post("/account-deletions", status_code=204, response_model=None)
def delete_account(
    payload: AccountDeletionRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[AccountDeletionService, Depends(get_account_deletion_service)],
    rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_account_deletion_rate_limiter),
    ],
) -> Response | JSONResponse:
    if payload.confirmation != "DELETE":
        return build_error_response(
            request=request,
            status_code=400,
            code="deletion_confirmation_required",
            message="The exact DELETE confirmation is required.",
        )
    decision = rate_limiter.allow(str(claims.user_id))
    if not decision.allowed:
        return build_error_response(
            request=request,
            status_code=429,
            code="rate_limit_exceeded",
            message="Too many account-deletion attempts. Please try again later.",
            headers=retry_after_headers(decision),
        )
    try:
        service.delete(user_id=claims.user_id, current_password=payload.current_password)
    except CurrentPasswordIncorrectError:
        return build_error_response(
            request=request,
            status_code=401,
            code="current_password_incorrect",
            message="The current password is incorrect.",
        )
    return Response(status_code=204)
