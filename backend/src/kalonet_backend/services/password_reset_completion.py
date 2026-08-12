from collections.abc import Callable
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from kalonet_backend.core.security import hash_opaque_token, hash_password
from kalonet_backend.repositories import (
    PasswordResetTokenRepository,
    RefreshSessionRepository,
    UserRepository,
)


class InvalidOrExpiredResetTokenError(ValueError):
    """Raised when a reset token cannot be used exactly once."""


class PasswordResetCompletionService:
    """Complete a password reset as one atomic security transaction."""

    def __init__(
        self,
        session: Session,
        *,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._clock = clock
        self._reset_tokens = PasswordResetTokenRepository(session)
        self._users = UserRepository(session)
        self._refresh_sessions = RefreshSessionRepository(session)

    def complete(self, *, reset_token: str, new_password: str) -> None:
        """Consume a valid token, change the password, and revoke sessions."""

        now = self._clock()

        try:
            token_hash = hash_opaque_token(reset_token)
        except ValueError as error:
            raise InvalidOrExpiredResetTokenError from error

        candidate_token = self._reset_tokens.get_by_token_hash(token_hash)

        if (
            candidate_token is None
            or candidate_token.consumed_at is not None
            or candidate_token.invalidated_at is not None
            or candidate_token.expires_at <= now
        ):
            raise InvalidOrExpiredResetTokenError

        # Request creation locks user -> token rows. Keep the same order here
        # to avoid a deadlock when request and completion overlap.
        user = self._users.get_by_id_for_update(candidate_token.user_id)

        if user is None:
            raise InvalidOrExpiredResetTokenError

        stored_token = self._reset_tokens.get_by_token_hash_for_update(token_hash)

        if (
            stored_token is None
            or stored_token.user_id != user.id
            or stored_token.consumed_at is not None
            or stored_token.invalidated_at is not None
            or stored_token.expires_at <= now
        ):
            raise InvalidOrExpiredResetTokenError

        try:
            user.password_hash = hash_password(new_password)
            self._reset_tokens.mark_consumed(stored_token, consumed_at=now)
            self._refresh_sessions.revoke_active_for_user(
                user_id=user.id,
                revoked_at=now,
                revocation_reason="password_reset",
            )
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
