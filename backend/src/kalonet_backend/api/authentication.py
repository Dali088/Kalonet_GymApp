from typing import Annotated, cast

from fastapi import APIRouter, Depends, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from kalonet_backend.api.errors import build_error_response
from kalonet_backend.api.rate_limit import (
    SlidingWindowRateLimiter,
    retry_after_headers,
)
from kalonet_backend.core.config import Settings, get_settings
from kalonet_backend.db.session import get_db_session
from kalonet_backend.schemas.authentication import (
    RegistrationRequest,
    SessionCreateRequest,
    SessionResponse,
    SessionUserResponse,
)
from kalonet_backend.services import (
    AuthenticationSessionResult,
    AuthenticationTokenService,
    EmailAlreadyRegisteredError,
    InvalidCredentialsError,
    LoginService,
    RegistrationService,
)

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["Authentication"],
)


def get_registration_service(
    session: Annotated[Session, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> RegistrationService:
    """Build the EP1 registration use-case service."""

    return RegistrationService(
        session,
        AuthenticationTokenService(settings),
    )


def get_login_service(
    session: Annotated[Session, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> LoginService:
    """Build the EP2 login use-case service."""

    return LoginService(
        session,
        AuthenticationTokenService(settings),
    )


def get_login_email_failure_rate_limiter(
    request: Request,
) -> SlidingWindowRateLimiter:
    """Return the shared failed-login limiter keyed by normalized email."""

    return cast(
        SlidingWindowRateLimiter,
        request.app.state.login_email_failure_rate_limiter,
    )


def _to_session_response(
    result: AuthenticationSessionResult,
) -> SessionResponse:
    """Map the transport-neutral session result to the API representation."""

    return SessionResponse(
        access_token=result.access_token,
        refresh_token=result.refresh_token,
        access_token_expires_in_seconds=(result.access_token_expires_in_seconds),
        refresh_token_expires_at=result.refresh_token_expires_at,
        user=SessionUserResponse(
            id=str(result.user_id),
            email=result.email,
            onboarding_completed=result.onboarding_completed,
        ),
    )


@router.post(
    "/registrations",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_account(
    payload: RegistrationRequest,
    request: Request,
    service: Annotated[
        RegistrationService,
        Depends(get_registration_service),
    ],
) -> SessionResponse | JSONResponse:
    """EP1: create an account and immediately start a session."""

    try:
        result = service.register(
            email=str(payload.email),
            password=payload.password,
        )

    except EmailAlreadyRegisteredError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_409_CONFLICT,
            code="email_already_registered",
            message="An account with this email already exists.",
        )

    return _to_session_response(result)


@router.post(
    "/sessions",
    response_model=SessionResponse,
    status_code=status.HTTP_200_OK,
)
def login_account(
    payload: SessionCreateRequest,
    request: Request,
    service: Annotated[
        LoginService,
        Depends(get_login_service),
    ],
    email_failure_rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_login_email_failure_rate_limiter),
    ],
) -> SessionResponse | JSONResponse:
    """EP2: verify credentials and create a new authenticated session."""

    try:
        result = service.login(
            email=payload.email,
            password=payload.password,
        )

    except InvalidCredentialsError:
        decision = email_failure_rate_limiter.allow(payload.email)

        if not decision.allowed:
            return build_error_response(
                request=request,
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                code="rate_limit_exceeded",
                message="Too many authentication attempts. Please try again later.",
                headers=retry_after_headers(decision),
            )

        return build_error_response(
            request=request,
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="invalid_credentials",
            message="Email or password is incorrect.",
        )

    return _to_session_response(result)
