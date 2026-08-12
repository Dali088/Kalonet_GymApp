from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import PasswordResetToken


class PasswordResetTokenRepository:
    """Database operations for one-time password-reset tokens."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def invalidate_active_for_user(
        self,
        *,
        user_id: UUID,
        invalidated_at: datetime,
        now: datetime,
    ) -> int:
        """Invalidate unused, unexpired reset tokens for one user."""

        statement = (
            select(PasswordResetToken)
            .where(
                PasswordResetToken.user_id == user_id,
                PasswordResetToken.consumed_at.is_(None),
                PasswordResetToken.invalidated_at.is_(None),
                PasswordResetToken.expires_at > now,
            )
            .with_for_update()
        )
        active_tokens = list(self._session.scalars(statement))

        for reset_token in active_tokens:
            reset_token.invalidated_at = invalidated_at

        self._session.flush()

        return len(active_tokens)

    def create(
        self,
        *,
        user_id: UUID,
        token_hash: str,
        expires_at: datetime,
    ) -> PasswordResetToken:
        """Persist one hashed reset token without committing."""

        reset_token = PasswordResetToken(
            id=uuid4(),
            user_id=user_id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        self._session.add(reset_token)
        self._session.flush()

        return reset_token

    def get_by_token_hash_for_update(
        self,
        token_hash: str,
    ) -> PasswordResetToken | None:
        """Find and lock one reset token for a completion transaction."""

        statement = (
            select(PasswordResetToken)
            .where(PasswordResetToken.token_hash == token_hash)
            .with_for_update()
        )

        return self._session.scalar(statement)

    def get_by_token_hash(
        self,
        token_hash: str,
    ) -> PasswordResetToken | None:
        """Find one reset token without taking a row lock."""

        statement = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)

        return self._session.scalar(statement)

    def mark_consumed(
        self,
        reset_token: PasswordResetToken,
        *,
        consumed_at: datetime,
    ) -> None:
        """Mark a valid reset token as consumed without committing."""

        reset_token.consumed_at = consumed_at
        self._session.flush()
