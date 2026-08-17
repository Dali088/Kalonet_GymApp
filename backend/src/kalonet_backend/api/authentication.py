from typing import Annotated, cast

from fastapi import APIRouter, Depends, Request, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from kalonet_backend.api.dependencies import get_current_access_token_claims
from kalonet_backend.api.errors import build_error_response
from kalonet_backend.api.rate_limit import (
    SlidingWindowRateLimiter,
    retry_after_headers,
)
from kalonet_backend.core.config import Settings, get_settings
from kalonet_backend.core.security import (
    AccessTokenClaims,
    hash_opaque_token,
)
from kalonet_backend.db.session import get_db_session
from kalonet_backend.repositories import RefreshSessionRepository
from kalonet_backend.schemas.authentication import (
    LogoutRequest,
    PasswordResetCompletionRequest,
    PasswordResetRequest,
    PasswordResetRequestResponse,
    RefreshTokenRequest,
    RegistrationRequest,
    SessionCreateRequest,
    SessionResponse,
    SessionUserResponse,
)
from kalonet_backend.schemas.personalization import PasswordChangeRequest
from kalonet_backend.services import (
    AuthenticationSessionResult,
    AuthenticationTokenService,
    CurrentPasswordIncorrectError,
    EmailAlreadyRegisteredError,
    InvalidCredentialsError,
    InvalidOrExpiredResetTokenError,
    InvalidRefreshTokenError,
    LoginService,
    LogoutService,
    NewPasswordMatchesCurrentError,
    PasswordChangeService,
    PasswordResetCompletionService,
    PasswordResetRequestService,
    RefreshTokenReuseDetectedError,
    RefreshTokenService,
    RegistrationService,
    SessionMismatchError,
)
from kalonet_backend.services.email import SmtpEmailSender

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


def get_refresh_token_service(
    session: Annotated[Session, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> RefreshTokenService:
    """Build the EP3 refresh-token rotation service."""

    return RefreshTokenService(
        session,
        AuthenticationTokenService(settings),
    )


def get_logout_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> LogoutService:
    """Build the EP3 logout service."""

    return LogoutService(session)


def get_password_reset_request_service(
    session: Annotated[Session, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> PasswordResetRequestService:
    """Build the password-reset request service."""

    return PasswordResetRequestService(session, SmtpEmailSender(settings))


def get_password_reset_completion_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> PasswordResetCompletionService:
    """Build the password-reset completion service."""

    return PasswordResetCompletionService(session)


def get_login_email_failure_rate_limiter(
    request: Request,
) -> SlidingWindowRateLimiter:
    """Return the shared failed-login limiter keyed by normalized email."""

    return cast(
        SlidingWindowRateLimiter,
        request.app.state.login_email_failure_rate_limiter,
    )


def get_refresh_rate_limiter(
    request: Request,
) -> SlidingWindowRateLimiter:
    """Return the shared refresh-token family limiter."""

    return cast(
        SlidingWindowRateLimiter,
        request.app.state.refresh_rate_limiter,
    )


def get_password_reset_email_rate_limiter(
    request: Request,
) -> SlidingWindowRateLimiter:
    """Return the shared reset limiter keyed by normalized email."""

    return cast(
        SlidingWindowRateLimiter,
        request.app.state.password_reset_email_rate_limiter,
    )


def get_password_reset_token_rate_limiter(
    request: Request,
) -> SlidingWindowRateLimiter:
    """Return the shared reset limiter keyed by token fingerprint."""

    return cast(
        SlidingWindowRateLimiter,
        request.app.state.password_reset_token_rate_limiter,
    )


def get_password_change_rate_limiter(request: Request) -> SlidingWindowRateLimiter:
    """Return the authenticated password-change limiter."""

    return cast(SlidingWindowRateLimiter, request.app.state.password_change_rate_limiter)


def get_password_change_service(
    session: Annotated[Session, Depends(get_db_session)],
) -> PasswordChangeService:
    return PasswordChangeService(session)


def _get_refresh_family_key(
    session: Session,
    refresh_token: str,
) -> str | None:
    """Resolve a known refresh token to its token-family limiter key."""

    try:
        token_hash = hash_opaque_token(refresh_token)
    except ValueError:
        return None

    refresh_session = RefreshSessionRepository(session).get_by_token_hash(token_hash)

    if refresh_session is None:
        return None

    return str(refresh_session.family_id)


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


@router.post(
    "/token-refreshes",
    response_model=SessionResponse,
    status_code=status.HTTP_200_OK,
)
def refresh_session(
    payload: RefreshTokenRequest,
    request: Request,
    session: Annotated[Session, Depends(get_db_session)],
    service: Annotated[
        RefreshTokenService,
        Depends(get_refresh_token_service),
    ],
    rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_refresh_rate_limiter),
    ],
) -> SessionResponse | JSONResponse:
    """EP3: rotate a valid refresh token and issue its replacement."""

    family_key = _get_refresh_family_key(session, payload.refresh_token)

    if family_key is not None:
        decision = rate_limiter.allow(family_key)

        if not decision.allowed:
            return build_error_response(
                request=request,
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                code="rate_limit_exceeded",
                message="Too many refresh attempts. Please try again later.",
                headers=retry_after_headers(decision),
            )

    try:
        result = service.rotate(refresh_token=payload.refresh_token)

    except RefreshTokenReuseDetectedError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="refresh_token_reuse_detected",
            message="The refresh token was already used and its token family was revoked.",
        )

    except InvalidRefreshTokenError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="invalid_refresh_token",
            message="The refresh token is invalid or expired.",
        )

    return _to_session_response(result)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
def logout_current_session(
    payload: LogoutRequest,
    request: Request,
    service: Annotated[LogoutService, Depends(get_logout_service)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
) -> Response | JSONResponse:
    """EP3: revoke the authenticated refresh session."""

    try:
        service.logout(
            user_id=claims.user_id,
            session_id=claims.session_id,
            refresh_token=payload.refresh_token,
        )
    except SessionMismatchError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_400_BAD_REQUEST,
            code="session_mismatch",
            message="The refresh token does not belong to the authenticated session.",
        )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/password-reset-requests",
    response_model=PasswordResetRequestResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def request_password_reset(
    payload: PasswordResetRequest,
    request: Request,
    service: Annotated[
        PasswordResetRequestService,
        Depends(get_password_reset_request_service),
    ],
    email_rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_password_reset_email_rate_limiter),
    ],
) -> PasswordResetRequestResponse | JSONResponse:
    """EP1 authentication support: start password recovery generically."""

    decision = email_rate_limiter.allow(str(payload.email))

    if not decision.allowed:
        return build_error_response(
            request=request,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            code="rate_limit_exceeded",
            message="Too many password-reset requests. Please try again later.",
            headers=retry_after_headers(decision),
        )

    service.request(email=str(payload.email))

    return PasswordResetRequestResponse(
        message=("If an account exists for that email, password-reset instructions will be sent.")
    )


@router.post(
    "/password-resets",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
def complete_password_reset(
    payload: PasswordResetCompletionRequest,
    request: Request,
    service: Annotated[
        PasswordResetCompletionService,
        Depends(get_password_reset_completion_service),
    ],
    token_rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_password_reset_token_rate_limiter),
    ],
) -> Response | JSONResponse:
    """Consume a reset token and atomically change the password."""

    token_fingerprint = hash_opaque_token(payload.reset_token)
    decision = token_rate_limiter.allow(token_fingerprint)

    if not decision.allowed:
        return build_error_response(
            request=request,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            code="rate_limit_exceeded",
            message="Too many password-reset attempts. Please try again later.",
            headers=retry_after_headers(decision),
        )

    try:
        service.complete(
            reset_token=payload.reset_token,
            new_password=payload.new_password,
        )
    except InvalidOrExpiredResetTokenError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_400_BAD_REQUEST,
            code="invalid_or_expired_reset_token",
            message="The password-reset token is invalid, expired, or already used.",
        )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/password-changes",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
def change_password(
    payload: PasswordChangeRequest,
    request: Request,
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    service: Annotated[PasswordChangeService, Depends(get_password_change_service)],
    rate_limiter: Annotated[
        SlidingWindowRateLimiter,
        Depends(get_password_change_rate_limiter),
    ],
) -> Response | JSONResponse:
    decision = rate_limiter.allow(str(claims.user_id))
    if not decision.allowed:
        return build_error_response(
            request=request,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            code="rate_limit_exceeded",
            message="Too many password-change attempts. Please try again later.",
            headers=retry_after_headers(decision),
        )

    try:
        service.change(
            user_id=claims.user_id,
            current_password=payload.current_password,
            new_password=payload.new_password,
        )
    except CurrentPasswordIncorrectError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="current_password_incorrect",
            message="The current password is incorrect.",
        )
    except NewPasswordMatchesCurrentError:
        return build_error_response(
            request=request,
            status_code=status.HTTP_400_BAD_REQUEST,
            code="new_password_matches_current",
            message="The new password must differ from the current password.",
        )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
