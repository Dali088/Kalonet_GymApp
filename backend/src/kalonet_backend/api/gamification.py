from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from kalonet_backend.api.dependencies import get_current_access_token_claims
from kalonet_backend.api.errors import build_error_response
from kalonet_backend.core.security import AccessTokenClaims
from kalonet_backend.db.session import get_db_session
from kalonet_backend.schemas.gamification import (
    GamificationSummaryResponse,
    LeaderboardResponse,
)
from kalonet_backend.services.gamification import (
    GamificationOnboardingRequiredError,
    GamificationService,
)

router = APIRouter(prefix="/api/v1/users/me/gamification", tags=["Gamification"])


def get_gamification_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> GamificationService:
    return GamificationService(session)


def _onboarding_error(request: Request) -> JSONResponse:
    return build_error_response(
        request=request,
        status_code=403,
        code="onboarding_required",
        message="Complete onboarding before viewing gamification.",
    )


@router.get("", response_model=GamificationSummaryResponse)
def get_gamification_summary(
    request: Request,
    date: Annotated[date, Query(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[GamificationService, Depends(get_gamification_service)],
) -> GamificationSummaryResponse | JSONResponse:
    try:
        return service.get_summary(claims.user_id, date)
    except GamificationOnboardingRequiredError:
        return _onboarding_error(request)


@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_gamification_leaderboard(
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[GamificationService, Depends(get_gamification_service)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> LeaderboardResponse | JSONResponse:
    try:
        return service.get_leaderboard(claims.user_id, limit, offset)
    except GamificationOnboardingRequiredError:
        return _onboarding_error(request)
