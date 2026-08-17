from collections.abc import Callable
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.orm import Session

from kalonet_backend.core.security import hash_password, verify_password_for_login
from kalonet_backend.repositories import RefreshSessionRepository, UserRepository


class CurrentPasswordIncorrectError(ValueError):
    """Raised when the supplied current password is not correct."""


class NewPasswordMatchesCurrentError(ValueError):
    """Raised when a password change would leave the credential unchanged."""


class PasswordChangeService:
    """Change a password and revoke all existing sessions atomically."""

    def __init__(
        self,
        session: Session,
        *,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._clock = clock
        self._users = UserRepository(session)
        self._refresh_sessions = RefreshSessionRepository(session)

    def change(self, *, user_id: UUID, current_password: str, new_password: str) -> None:
        try:
            user = self._users.get_by_id_for_update(user_id)
            if user is None or not verify_password_for_login(current_password, user.password_hash):
                raise CurrentPasswordIncorrectError
            if verify_password_for_login(new_password, user.password_hash):
                raise NewPasswordMatchesCurrentError

            user.password_hash = hash_password(new_password)
            self._refresh_sessions.revoke_active_for_user(
                user_id=user.id,
                revoked_at=self._clock(),
                revocation_reason="password_change",
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
