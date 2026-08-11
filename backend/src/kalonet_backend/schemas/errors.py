from typing import Any

from pydantic import BaseModel, Field


class ErrorDetail(BaseModel):
    """One optional field-level error detail."""

    field: str | None = None
    message: str


class ErrorBody(BaseModel):
    """Stable Kalonet API error representation."""

    code: str
    message: str
    details: list[ErrorDetail | dict[str, Any]] = Field(default_factory=list)
    request_id: str


class ErrorResponse(BaseModel):
    """Top-level Kalonet error envelope."""

    error: ErrorBody
