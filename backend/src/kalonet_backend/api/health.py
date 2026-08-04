from typing import Annotated, Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from kalonet_backend.core.config import Settings, get_settings

router = APIRouter(tags=["Operations"])


class HealthResponse(BaseModel):
    """Response returned by the process health endpoint."""

    status: Literal["ok"]
    service: str
    version: str
    environment: str


@router.get("/health", response_model=HealthResponse)
def get_health(
    settings: Annotated[Settings, Depends(get_settings)],
) -> HealthResponse:
    """Report whether the API process is running."""

    return HealthResponse(
        status="ok",
        service=settings.app_name,
        version=settings.app_version,
        environment=settings.environment,
    )
