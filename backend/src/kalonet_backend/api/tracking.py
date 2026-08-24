from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, Query, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from kalonet_backend.api.dependencies import get_current_access_token_claims
from kalonet_backend.api.errors import build_error_response
from kalonet_backend.core.security import AccessTokenClaims
from kalonet_backend.db.session import get_db_session
from kalonet_backend.schemas.tracking import (
    ActivityCreate,
    ActivityListResponse,
    ActivityResponse,
    ActivityUpdate,
    DailyDashboardResponse,
    DailyStepsResponse,
    DailyStepsUpdate,
    MealCreate,
    MealItemCreate,
    MealItemCreatedResponse,
    MealItemUpdate,
    MealResponse,
    MealsResponse,
    MealUpdate,
    WaterCreatedResponse,
    WaterEntryCreate,
    WaterEntryUpdate,
    WaterListResponse,
)
from kalonet_backend.services.tracking import (
    ActiveNutritionTargetNotFoundError,
    ActivityNotFoundError,
    FutureDateNotAllowedError,
    MealItemNotFoundError,
    MealNotFoundError,
    OnboardingRequiredError,
    TrackingService,
    WaterEntryNotFoundError,
)

router = APIRouter(prefix="/api/v1", tags=["Tracking"])


def get_tracking_service(session: Annotated[Session, Depends(get_db_session)]) -> TrackingService:
    return TrackingService(session)


def _error(request: Request, status_code: int, code: str, message: str) -> JSONResponse:
    return build_error_response(
        request=request, status_code=status_code, code=code, message=message
    )


def _map_tracking_error(request: Request, exc: Exception) -> JSONResponse:
    mapping: dict[type[Exception], tuple[int, str, str]] = {
        FutureDateNotAllowedError: (
            400,
            "future_date_not_allowed",
            "Future dates are not allowed for tracking writes.",
        ),
        MealNotFoundError: (404, "meal_not_found", "The meal was not found."),
        MealItemNotFoundError: (404, "meal_item_not_found", "The meal item was not found."),
        WaterEntryNotFoundError: (404, "water_entry_not_found", "The water entry was not found."),
        ActivityNotFoundError: (404, "activity_not_found", "The activity was not found."),
    }
    status_code, code, message = mapping[type(exc)]
    return _error(request, status_code, code, message)


def _key_header(value: Annotated[str | None, Header(alias="Idempotency-Key")] = None) -> str | None:
    return value


@router.get("/users/me/daily-dashboard", response_model=DailyDashboardResponse)
def daily_dashboard(
    date: Annotated[date, Query(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    request: Request,
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> DailyDashboardResponse | JSONResponse:
    try:
        return service.dashboard_for_date(claims.user_id, date)
    except OnboardingRequiredError:
        return _error(
            request, 403, "onboarding_required", "Complete onboarding before viewing the dashboard."
        )
    except ActiveNutritionTargetNotFoundError:
        return _error(
            request, 404, "active_nutrition_target_not_found", "No active nutrition target exists."
        )


@router.get("/users/me/meals", response_model=MealsResponse)
def list_meals(
    date: Annotated[date, Query(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> MealsResponse:
    return service.list_meals(claims.user_id, date)


@router.post("/users/me/meals", response_model=MealResponse, status_code=201)
def create_meal(
    payload: MealCreate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
    key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> MealResponse | JSONResponse:
    try:
        result = service.create_meal(claims.user_id, payload, key)
        return (
            JSONResponse(
                status_code=result.status_code,
                content=result.body if result.replay else result.body.model_dump(mode="json"),
            )
            if result.replay
            else result.body
        )
    except FutureDateNotAllowedError as exc:
        return _map_tracking_error(request, exc)
    except ValueError:
        return _error(request, 422, "validation_error", "The meal payload is invalid.")
    except Exception as exc:
        from kalonet_backend.repositories.idempotency import (
            IdempotencyConflictError,
            IdempotencyInProgressError,
        )

        if isinstance(exc, IdempotencyConflictError):
            return _error(
                request,
                409,
                "idempotency_key_conflict",
                "The idempotency key was reused with different input.",
            )
        if isinstance(exc, IdempotencyInProgressError):
            return _error(
                request,
                409,
                "idempotency_request_in_progress",
                "An equivalent request is already being processed.",
            )
        raise


@router.get("/users/me/meals/{meal_id}", response_model=MealResponse)
def get_meal(
    meal_id: UUID,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> MealResponse | JSONResponse:
    try:
        return service.get_meal(claims.user_id, meal_id)
    except MealNotFoundError:
        return _error(request, 404, "meal_not_found", "The meal was not found.")


@router.patch("/users/me/meals/{meal_id}", response_model=MealResponse)
def update_meal(
    meal_id: UUID,
    payload: MealUpdate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> MealResponse | JSONResponse:
    try:
        return service.update_meal(claims.user_id, meal_id, payload)
    except (MealNotFoundError, FutureDateNotAllowedError) as exc:
        return _map_tracking_error(request, exc)


@router.post(
    "/users/me/meals/{meal_id}/items", response_model=MealItemCreatedResponse, status_code=201
)
def add_meal_item(
    meal_id: UUID,
    payload: MealItemCreate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
    key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> MealItemCreatedResponse | JSONResponse:
    try:
        result = service.add_item(claims.user_id, meal_id, payload, key)
        return (
            JSONResponse(status_code=result.status_code, content=result.body)
            if result.replay
            else result.body
        )
    except (MealNotFoundError, FutureDateNotAllowedError) as exc:
        return _map_tracking_error(request, exc)
    except ValueError:
        return _error(request, 422, "validation_error", "The meal item payload is invalid.")
    except Exception as exc:
        from kalonet_backend.repositories.idempotency import (
            IdempotencyConflictError,
            IdempotencyInProgressError,
        )

        if isinstance(exc, IdempotencyConflictError):
            return _error(
                request,
                409,
                "idempotency_key_conflict",
                "The idempotency key was reused with different input.",
            )
        if isinstance(exc, IdempotencyInProgressError):
            return _error(
                request,
                409,
                "idempotency_request_in_progress",
                "An equivalent request is already being processed.",
            )
        raise


@router.patch("/users/me/meals/{meal_id}/items/{item_id}", response_model=MealItemCreatedResponse)
def update_meal_item(
    meal_id: UUID,
    item_id: UUID,
    payload: MealItemUpdate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> MealItemCreatedResponse | JSONResponse:
    try:
        return service.update_item(claims.user_id, meal_id, item_id, payload)
    except MealItemNotFoundError:
        return _error(request, 404, "meal_item_not_found", "The meal item was not found.")


@router.delete("/users/me/meals/{meal_id}/items/{item_id}", status_code=204, response_model=None)
def delete_meal_item(
    meal_id: UUID,
    item_id: UUID,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> Response | JSONResponse:
    try:
        service.delete_item(claims.user_id, meal_id, item_id)
        return Response(status_code=204)
    except MealItemNotFoundError:
        return _error(request, 404, "meal_item_not_found", "The meal item was not found.")


@router.delete("/users/me/meals/{meal_id}", status_code=204, response_model=None)
def delete_meal(
    meal_id: UUID,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> Response | JSONResponse:
    try:
        service.delete_meal(claims.user_id, meal_id)
        return Response(status_code=204)
    except MealNotFoundError:
        return _error(request, 404, "meal_not_found", "The meal was not found.")


@router.get("/users/me/water-entries", response_model=WaterListResponse)
def list_water(
    date: Annotated[date, Query(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> WaterListResponse:
    return service.list_water(claims.user_id, date)


@router.post("/users/me/water-entries", response_model=WaterCreatedResponse, status_code=201)
def create_water(
    payload: WaterEntryCreate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
    key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> WaterCreatedResponse | JSONResponse:
    try:
        result = service.create_water(claims.user_id, payload, key)
        return (
            JSONResponse(status_code=result.status_code, content=result.body)
            if result.replay
            else result.body
        )
    except FutureDateNotAllowedError:
        return _error(
            request,
            400,
            "future_date_not_allowed",
            "Future dates are not allowed for tracking writes.",
        )
    except ValueError:
        return _error(request, 422, "validation_error", "The water payload is invalid.")
    except Exception as exc:
        from kalonet_backend.repositories.idempotency import (
            IdempotencyConflictError,
            IdempotencyInProgressError,
        )

        if isinstance(exc, IdempotencyConflictError):
            return _error(
                request,
                409,
                "idempotency_key_conflict",
                "The idempotency key was reused with different input.",
            )
        if isinstance(exc, IdempotencyInProgressError):
            return _error(
                request,
                409,
                "idempotency_request_in_progress",
                "An equivalent request is already being processed.",
            )
        raise


@router.patch("/users/me/water-entries/{water_entry_id}", response_model=WaterCreatedResponse)
def update_water(
    water_entry_id: UUID,
    payload: WaterEntryUpdate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> WaterCreatedResponse | JSONResponse:
    try:
        return service.update_water(claims.user_id, water_entry_id, payload)
    except (WaterEntryNotFoundError, FutureDateNotAllowedError) as exc:
        return _map_tracking_error(request, exc)


@router.delete("/users/me/water-entries/{water_entry_id}", status_code=204, response_model=None)
def delete_water(
    water_entry_id: UUID,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> Response | JSONResponse:
    try:
        service.delete_water(claims.user_id, water_entry_id)
        return Response(status_code=204)
    except WaterEntryNotFoundError:
        return _error(request, 404, "water_entry_not_found", "The water entry was not found.")


@router.get("/users/me/daily-steps/{date}", response_model=DailyStepsResponse)
def get_steps(
    date: date,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> DailyStepsResponse:
    return service.get_steps(claims.user_id, date)


@router.put("/users/me/daily-steps/{date}", response_model=DailyStepsResponse)
def set_steps(
    date: date,
    payload: DailyStepsUpdate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> DailyStepsResponse | JSONResponse:
    try:
        return service.set_steps(claims.user_id, date, payload)
    except FutureDateNotAllowedError:
        return _error(
            request,
            400,
            "future_date_not_allowed",
            "Future dates are not allowed for tracking writes.",
        )


@router.get("/users/me/activities", response_model=ActivityListResponse)
def list_activities(
    date: Annotated[date, Query(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> ActivityListResponse:
    return service.list_activities(claims.user_id, date)


@router.post("/users/me/activities", response_model=ActivityResponse, status_code=201)
def create_activity(
    payload: ActivityCreate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
    key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> ActivityResponse | JSONResponse:
    try:
        result = service.create_activity(claims.user_id, payload, key)
        return (
            JSONResponse(status_code=result.status_code, content=result.body)
            if result.replay
            else result.body
        )
    except FutureDateNotAllowedError:
        return _error(
            request,
            400,
            "future_date_not_allowed",
            "Future dates are not allowed for tracking writes.",
        )
    except ValueError:
        return _error(request, 422, "validation_error", "The activity payload is invalid.")
    except Exception as exc:
        from kalonet_backend.repositories.idempotency import (
            IdempotencyConflictError,
            IdempotencyInProgressError,
        )

        if isinstance(exc, IdempotencyConflictError):
            return _error(
                request,
                409,
                "idempotency_key_conflict",
                "The idempotency key was reused with different input.",
            )
        if isinstance(exc, IdempotencyInProgressError):
            return _error(
                request,
                409,
                "idempotency_request_in_progress",
                "An equivalent request is already being processed.",
            )
        raise


@router.patch("/users/me/activities/{activity_id}", response_model=ActivityResponse)
def update_activity(
    activity_id: UUID,
    payload: ActivityUpdate,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> ActivityResponse | JSONResponse:
    try:
        return service.update_activity(claims.user_id, activity_id, payload)
    except (ActivityNotFoundError, FutureDateNotAllowedError) as exc:
        return _map_tracking_error(request, exc)


@router.delete("/users/me/activities/{activity_id}", status_code=204, response_model=None)
def delete_activity(
    activity_id: UUID,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[TrackingService, Depends(get_tracking_service)],
) -> Response | JSONResponse:
    try:
        service.delete_activity(claims.user_id, activity_id)
        return Response(status_code=204)
    except ActivityNotFoundError:
        return _error(request, 404, "activity_not_found", "The activity was not found.")
