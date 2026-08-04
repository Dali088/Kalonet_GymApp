from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Validated application configuration."""

    app_name: str = "Kalonet API"
    app_version: str = "0.1.0"
    environment: Literal["development", "test", "production"] = "development"
    docs_enabled: bool = True

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
