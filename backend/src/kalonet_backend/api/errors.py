from typing import Any

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from kalonet_backend.api.request_context import get_request_id
from kalonet_backend.core.security import InvalidAccessTokenError
from kalonet_backend.schemas.errors import (
    ErrorBody,
    ErrorDetail,
    ErrorResponse,
)


def build_error_response(
    *,
    request: Request,
    status_code: int,
    code: str,
    message: str,
    details: list[ErrorDetail | dict[str, Any]] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    """Build one response using Kalonet's standard error contract."""

    response = ErrorResponse(
        error=ErrorBody(
            code=code,
            message=message,
            details=details or [],
            request_id=get_request_id(request),
        )
    )

    return JSONResponse(
        status_code=status_code,
        content=response.model_dump(mode="json"),
        headers=headers,
    )


async def invalid_access_token_error_handler(
    request: Request,
    exception: Exception,
) -> JSONResponse:
    """Translate protected-route authentication failures into Kalonet errors."""

    if not isinstance(exception, InvalidAccessTokenError):
        raise exception

    return build_error_response(
        request=request,
        status_code=401,
        code="invalid_access_token",
        message="The access token is missing or invalid.",
    )


async def request_validation_error_handler(
    request: Request,
    exception: Exception,
) -> JSONResponse:
    """Translate FastAPI validation failures into Kalonet errors."""

    if not isinstance(exception, RequestValidationError):
        raise exception

    details: list[ErrorDetail | dict[str, Any]] = []

    for error in exception.errors():
        location = [str(part) for part in error.get("loc", ()) if part != "body"]

        field = ".".join(location) or None

        details.append(
            ErrorDetail(
                field=field,
                message=str(error.get("msg", "Invalid value.")),
            )
        )

    return build_error_response(
        request=request,
        status_code=422,
        code="validation_error",
        message="Request validation failed.",
        details=details,
    )
