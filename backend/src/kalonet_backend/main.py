from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from datetime import timedelta
from typing import cast

from fastapi import FastAPI, Request, Response, status
from fastapi.exceptions import RequestValidationError
from sqlalchemy import Engine

from kalonet_backend.api.authentication import (
    router as authentication_router,
)
from kalonet_backend.api.errors import (
    build_error_response,
    request_validation_error_handler,
)
from kalonet_backend.api.health import router as health_router
from kalonet_backend.api.rate_limit import (
    SlidingWindowRateLimiter,
    retry_after_headers,
)
from kalonet_backend.core.config import Settings, get_settings
from kalonet_backend.db.session import (
    create_database_engine,
    create_session_factory,
)


def create_app(
    settings: Settings | None = None,
    database_engine: Engine | None = None,
) -> FastAPI:
    """Create and configure a Kalonet FastAPI application."""

    resolved_settings = settings or get_settings()
    resolved_engine = database_engine or create_database_engine(resolved_settings)
    session_factory = create_session_factory(resolved_engine)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        """Manage application-level resources."""

        yield
        resolved_engine.dispose()

    app = FastAPI(
        title=resolved_settings.app_name,
        version=resolved_settings.app_version,
        docs_url="/docs" if resolved_settings.docs_enabled else None,
        redoc_url="/redoc" if resolved_settings.docs_enabled else None,
        openapi_url="/openapi.json" if resolved_settings.docs_enabled else None,
        lifespan=lifespan,
    )

    app.add_exception_handler(
        RequestValidationError,
        request_validation_error_handler,
    )

    def provide_settings() -> Settings:
        return resolved_settings

    app.dependency_overrides[get_settings] = provide_settings
    app.state.database_engine = resolved_engine
    app.state.session_factory = session_factory
    app.state.registration_rate_limiter = SlidingWindowRateLimiter(
        limit=5,
        window=timedelta(hours=1),
    )
    app.state.login_ip_rate_limiter = SlidingWindowRateLimiter(
        limit=10,
        window=timedelta(minutes=15),
    )
    app.state.login_email_failure_rate_limiter = SlidingWindowRateLimiter(
        limit=5,
        window=timedelta(minutes=15),
    )

    @app.middleware("http")
    async def enforce_authentication_rate_limits(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        """Limit registration and login requests before body validation."""

        if request.method != "POST":
            return await call_next(request)

        if request.url.path == "/api/v1/auth/registrations":
            limiter = cast(
                SlidingWindowRateLimiter,
                request.app.state.registration_rate_limiter,
            )
        elif request.url.path == "/api/v1/auth/sessions":
            limiter = cast(
                SlidingWindowRateLimiter,
                request.app.state.login_ip_rate_limiter,
            )
        else:
            return await call_next(request)

        client_host = request.client.host if request.client and request.client.host else "unknown"
        decision = limiter.allow(client_host)

        if not decision.allowed:
            return build_error_response(
                request=request,
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                code="rate_limit_exceeded",
                message="Too many authentication attempts. Please try again later.",
                headers=retry_after_headers(decision),
            )

        return await call_next(request)

    app.include_router(health_router)
    app.include_router(authentication_router)

    return app


app = create_app()


def run() -> None:
    """Run the development API server."""

    import uvicorn

    uvicorn.run(
        "kalonet_backend.main:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
    )
