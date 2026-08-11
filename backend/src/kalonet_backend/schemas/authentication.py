from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from kalonet_backend.core.security.password_policy import (
    validate_new_password,
)


def normalize_email_input(value: object) -> object:
    """Trim and lowercase an email-like string."""

    if not isinstance(value, str):
        return value

    normalized_email = value.strip().lower()

    if not normalized_email:
        raise ValueError("Email must not be empty.")

    return normalized_email


class RegistrationRequest(BaseModel):
    """Request body for EP1 account registration."""

    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(max_length=320)
    password: str

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return normalize_email_input(value)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        return validate_new_password(value)


class SessionCreateRequest(BaseModel):
    """Request body for EP2 email/password login."""

    model_config = ConfigDict(extra="forbid")

    email: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return normalize_email_input(value)


class SessionUserResponse(BaseModel):
    """Authenticated user data returned to Flutter."""

    id: str = Field(min_length=1)
    email: EmailStr
    onboarding_completed: bool


class SessionResponse(BaseModel):
    """Shared EP1, EP2, and EP3 session representation."""

    access_token: str = Field(min_length=1)
    refresh_token: str = Field(min_length=1)
    token_type: Literal["bearer"] = "bearer"
    access_token_expires_in_seconds: int = Field(gt=0)
    refresh_token_expires_at: datetime
    user: SessionUserResponse
