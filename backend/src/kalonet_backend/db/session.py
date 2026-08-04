from collections.abc import Generator

from fastapi import Request
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from kalonet_backend.core.config import Settings

SessionFactory = sessionmaker[Session]


def create_database_engine(settings: Settings) -> Engine:
    """Create a SQLAlchemy engine from validated application settings."""

    return create_engine(
        settings.database_url,
        pool_pre_ping=True,
    )


def create_session_factory(engine: Engine) -> SessionFactory:
    """Create sessions bound to the supplied database engine."""

    return sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )


def get_db_session(request: Request) -> Generator[Session, None, None]:
    """Provide one SQLAlchemy session for one HTTP request."""

    session_factory: SessionFactory = request.app.state.session_factory

    with session_factory() as session:
        yield session
