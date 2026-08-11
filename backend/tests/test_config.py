from pydantic import SecretStr

from kalonet_backend.core.config import Settings

TEST_DATABASE_URL = "postgresql+psycopg://kalonet:kalonet_local_password@localhost:5433/kalonet"


def test_authentication_settings_have_local_defaults() -> None:
    settings = Settings(
        environment="test",
        database_url=TEST_DATABASE_URL,
    )

    assert isinstance(settings.jwt_secret_key, SecretStr)
    assert len(settings.jwt_secret_key.get_secret_value().encode("utf-8")) >= 32
    assert settings.access_token_lifetime_seconds == 900
    assert settings.refresh_token_lifetime_days == 30


def test_authentication_settings_accept_overrides() -> None:
    settings = Settings(
        environment="test",
        database_url=TEST_DATABASE_URL,
        jwt_secret_key=("test-jwt-secret-key-containing-at-least-32-bytes"),
        access_token_lifetime_seconds=600,
        refresh_token_lifetime_days=14,
    )

    assert (
        settings.jwt_secret_key.get_secret_value()
        == "test-jwt-secret-key-containing-at-least-32-bytes"
    )
    assert settings.access_token_lifetime_seconds == 600
    assert settings.refresh_token_lifetime_days == 14
