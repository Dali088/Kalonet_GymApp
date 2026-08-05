from collections.abc import Generator

import pytest
from sqlalchemy import Engine
from sqlalchemy.orm import Session

from kalonet_backend.core.config import Settings
from kalonet_backend.db.session import create_database_engine


@pytest.fixture
def database_engine() -> Generator[Engine, None, None]:
    """Provide a real PostgreSQL engine for integration tests."""

    settings = Settings(environment="test")
    engine = create_database_engine(settings)

    yield engine

    engine.dispose()


@pytest.fixture
def db_session(
    database_engine: Engine,
) -> Generator[Session, None, None]:
    """Provide a test transaction that is rolled back afterward."""

    connection = database_engine.connect()
    transaction = connection.begin()
    session = Session(
        bind=connection,
        autoflush=False,
        expire_on_commit=False,
    )

    try:
        yield session
    finally:
        session.close()

        if transaction.is_active:
            transaction.rollback()

        connection.close()
