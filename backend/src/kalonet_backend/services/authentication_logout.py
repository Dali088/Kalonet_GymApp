from collections.abc import Callable
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.orm import Session

from kalonet_backend.core.security import hash_opaque_token
from kalonet_backend.repositories import RefreshSessionRepository


class SessionMismatchError(ValueError):
    """Raised when the refresh token is not the authenticated session."""


def _utc_now() -> datetime:
    return datetime.now(UTC)


class LogoutService:
    """Revoke one authenticated refresh session atomically."""

    def __init__(
        self,
        session: Session,
        *,
        clock: Callable[[], datetime] = _utc_now,
    ) -> None:
        self._session = session
        self._clock = clock
        self._refresh_sessions = RefreshSessionRepository(session)

    def logout(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        refresh_token: str,
    ) -> None:
        """Revoke the authenticated session; repeated logout is harmless."""

        try:
            try:
                token_hash = hash_opaque_token(refresh_token)
            except ValueError as error:
                raise SessionMismatchError from error

            refresh_session = self._refresh_sessions.get_by_token_hash_for_update(
                token_hash,
            )

            if (
                refresh_session is None
                or refresh_session.user_id != user_id
                or refresh_session.id != session_id
                or refresh_session.rotated_at is not None
            ):
                raise SessionMismatchError

            self._refresh_sessions.revoke_session(
                refresh_session,
                revoked_at=self._clock(),
                revocation_reason="logout",
            )
            self._session.commit()

        except SessionMismatchError:
            self._session.rollback()
            raise
        except Exception:
            self._session.rollback()
            raise
