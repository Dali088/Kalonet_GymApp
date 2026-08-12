from collections.abc import Callable
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from kalonet_backend.core.security import issue_reset_token
from kalonet_backend.repositories import PasswordResetTokenRepository, UserRepository
from kalonet_backend.services.email import (
    EmailDeliveryError,
    PasswordResetEmail,
    SmtpEmailSender,
)


class PasswordResetRequestService:
    """Create reset tokens without revealing account existence."""

    def __init__(
        self,
        session: Session,
        email_sender: SmtpEmailSender,
        *,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._session = session
        self._email_sender = email_sender
        self._clock = clock
        self._users = UserRepository(session)
        self._reset_tokens = PasswordResetTokenRepository(session)

    def request(self, *, email: str) -> None:
        """Create and deliver a reset token when the account exists."""

        now = self._clock()
        user = self._users.get_by_email_for_update(email)

        if user is None:
            return

        issued_token = issue_reset_token(now=now)
        self._reset_tokens.invalidate_active_for_user(
            user_id=user.id,
            invalidated_at=now,
            now=now,
        )
        self._reset_tokens.create(
            user_id=user.id,
            token_hash=issued_token.token_hash,
            expires_at=issued_token.expires_at,
        )
        self._session.commit()

        try:
            self._email_sender.send_password_reset(
                PasswordResetEmail(
                    recipient=user.email,
                    reset_token=issued_token.plain_token,
                    expires_at=issued_token.expires_at,
                )
            )
        except EmailDeliveryError:
            # The public response must remain generic even when local delivery fails.
            return
