from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import Engine

from kalonet_backend.api.health import router as health_router
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

    def provide_settings() -> Settings:
        return resolved_settings

    app.dependency_overrides[get_settings] = provide_settings
    app.state.database_engine = resolved_engine
    app.state.session_factory = session_factory

    app.include_router(health_router)

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
