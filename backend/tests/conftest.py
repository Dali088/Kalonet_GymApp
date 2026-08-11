from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine
from sqlalchemy.orm import Session

from kalonet_backend.core.config import Settings
from kalonet_backend.db.session import create_database_engine, get_db_session
from kalonet_backend.main import create_app


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
        join_transaction_mode="create_savepoint",
    )

    try:
        yield session
    finally:
        session.close()

        if transaction.is_active:
            transaction.rollback()

        connection.close()


@pytest.fixture
def client(
    db_session: Session,
) -> Generator[TestClient, None, None]:
    """Provide a FastAPI client backed by the transactional test session."""

    settings = Settings(
        environment="test",
        docs_enabled=False,
        jwt_secret_key=("test-jwt-secret-key-containing-at-least-32-bytes"),
        access_token_lifetime_seconds=900,
        refresh_token_lifetime_days=30,
    )

    app = create_app(settings)

    def override_db_session() -> Generator[Session, None, None]:
        yield db_session

    app.dependency_overrides[get_db_session] = override_db_session

    with TestClient(app) as test_client:
        yield test_client
