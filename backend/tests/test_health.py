from fastapi.testclient import TestClient

from kalonet_backend.core.config import Settings
from kalonet_backend.main import create_app


def test_health_returns_application_status() -> None:
    settings = Settings(
        environment="test",
        docs_enabled=False,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "Kalonet API",
        "version": "0.1.0",
        "environment": "test",
    }


def test_docs_can_be_disabled() -> None:
    settings = Settings(
        environment="test",
        docs_enabled=False,
    )
    client = TestClient(create_app(settings))

    response = client.get("/docs")

    assert response.status_code == 404
