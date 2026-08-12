from datetime import UTC, datetime, timedelta
from smtplib import SMTPException
from unittest.mock import MagicMock, patch

import pytest

from kalonet_backend.core.config import Settings
from kalonet_backend.services.email import (
    EmailDeliveryError,
    PasswordResetEmail,
    SmtpEmailSender,
)


def create_settings() -> Settings:
    return Settings(
        environment="test",
        smtp_host="localhost",
        smtp_port=1025,
        email_from="no-reply@kalonet.local",
        password_reset_link_scheme="kalonet://password-reset",
    )


def test_smtp_sender_composes_password_reset_message() -> None:
    smtp_connection = MagicMock()
    smtp_context = smtp_connection.__enter__.return_value

    with patch(
        "kalonet_backend.services.email.SMTP",
        return_value=smtp_connection,
    ) as smtp_factory:
        SmtpEmailSender(create_settings()).send_password_reset(
            PasswordResetEmail(
                recipient="karim@example.com",
                reset_token="plain-reset-token",
                expires_at=datetime.now(UTC) + timedelta(minutes=30),
            )
        )

    smtp_factory.assert_called_once_with("localhost", 1025, timeout=10)
    sent_message = smtp_context.send_message.call_args.args[0]

    assert sent_message["From"] == "no-reply@kalonet.local"
    assert sent_message["To"] == "karim@example.com"
    assert "kalonet://password-reset?token=plain-reset-token" in sent_message.get_content()


def test_smtp_sender_translates_delivery_failure() -> None:
    smtp_connection = MagicMock()
    smtp_connection.__enter__.return_value.send_message.side_effect = SMTPException

    with (
        patch(
            "kalonet_backend.services.email.SMTP",
            return_value=smtp_connection,
        ),
        pytest.raises(EmailDeliveryError),
    ):
        SmtpEmailSender(create_settings()).send_password_reset(
            PasswordResetEmail(
                recipient="karim@example.com",
                reset_token="plain-reset-token",
                expires_at=datetime.now(UTC) + timedelta(minutes=30),
            )
        )
