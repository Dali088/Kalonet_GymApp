from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Validated application configuration."""

    app_name: str = "Kalonet API"
    app_version: str = "0.1.0"
    environment: Literal["development", "test", "production"] = "development"
    docs_enabled: bool = True

    jwt_secret_key: SecretStr = Field(
        default=SecretStr("local-development-secret-key-change-before-production"),
        min_length=32,
    )

    access_token_lifetime_seconds: int = Field(
        default=900,
        gt=0,
    )

    refresh_token_lifetime_days: int = Field(
        default=30,
        gt=0,
    )

    database_url: str = "postgresql+psycopg://kalonet:kalonet_local_password@localhost:5433/kalonet"

    model_config = SettingsConfigDict(
        env_prefix="KALONET_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Return one cached settings instance for normal application use."""

    return Settings()
