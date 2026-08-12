from dataclasses import dataclass
from datetime import datetime
from email.message import EmailMessage
from smtplib import SMTP, SMTPException

from kalonet_backend.core.config import Settings


class EmailDeliveryError(RuntimeError):
    """Raised when the configured email provider cannot accept a message."""


@dataclass(frozen=True, slots=True)
class PasswordResetEmail:
    """Values needed to compose a password-reset email."""

    recipient: str
    reset_token: str
    expires_at: datetime


class SmtpEmailSender:
    """Synchronous SMTP adapter for local Mailpit delivery."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def send_password_reset(self, email: PasswordResetEmail) -> None:
        message = EmailMessage()
        message["From"] = self._settings.email_from
        message["To"] = email.recipient
        message["Subject"] = "Reset your Kalonet password"
        reset_link = f"{self._settings.password_reset_link_scheme}?token={email.reset_token}"
        message.set_content(
            "If an account exists for this email, use the link below to reset your Kalonet "
            "password.\n\n"
            f"{reset_link}\n\n"
            "This link expires in 30 minutes and can only be used once."
        )

        try:
            with SMTP(self._settings.smtp_host, self._settings.smtp_port, timeout=10) as smtp:
                smtp.send_message(message)
        except (OSError, SMTPException) as error:
            raise EmailDeliveryError from error
