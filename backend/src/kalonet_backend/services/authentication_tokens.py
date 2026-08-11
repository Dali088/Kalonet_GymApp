from dataclasses import dataclass
from datetime import datetime, timedelta
from uuid import UUID

from kalonet_backend.core.config import Settings
from kalonet_backend.core.security import (
    IssuedRefreshToken,
    create_access_token,
    issue_refresh_token,
)


@dataclass(frozen=True, slots=True)
class IssuedSessionTokens:
    """Token values returned when an authenticated session is created."""

    access_token: str
    refresh_token: str
    refresh_token_hash: str
    access_token_expires_in_seconds: int
    refresh_token_expires_at: datetime


class AuthenticationTokenService:
    """Create access and refresh tokens using application settings."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def issue_session_tokens(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime | None = None,
    ) -> IssuedSessionTokens:
        refresh_token = self._issue_refresh_token(now=now)

        access_token = create_access_token(
            user_id=user_id,
            session_id=session_id,
            secret_key=self._settings.jwt_secret_key.get_secret_value(),
            now=now,
            lifetime=timedelta(seconds=self._settings.access_token_lifetime_seconds),
        )

        return IssuedSessionTokens(
            access_token=access_token,
            refresh_token=refresh_token.plain_token,
            refresh_token_hash=refresh_token.token_hash,
            access_token_expires_in_seconds=(self._settings.access_token_lifetime_seconds),
            refresh_token_expires_at=refresh_token.expires_at,
        )

    def _issue_refresh_token(
        self,
        *,
        now: datetime | None,
    ) -> IssuedRefreshToken:
        return issue_refresh_token(
            now=now,
            lifetime=timedelta(days=self._settings.refresh_token_lifetime_days),
        )
