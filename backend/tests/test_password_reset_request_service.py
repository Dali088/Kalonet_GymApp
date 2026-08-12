from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.core.security import hash_opaque_token
from kalonet_backend.models import PasswordResetToken
from kalonet_backend.repositories import UserRepository
from kalonet_backend.services import PasswordResetRequestService
from kalonet_backend.services.email import PasswordResetEmail


class RecordingEmailSender:
    def __init__(self) -> None:
        self.messages: list[PasswordResetEmail] = []

    def send_password_reset(self, email: PasswordResetEmail) -> None:
        self.messages.append(email)


def test_reset_request_creates_hashed_token_and_sends_email(
    db_session: Session,
) -> None:
    user = UserRepository(db_session).create(
        email="reset-service@example.com",
        password_hash="example-password-hash",
    )
    sender = RecordingEmailSender()
    now = datetime.now(UTC)
    service = PasswordResetRequestService(
        db_session,
        sender,
        clock=lambda: now,
    )

    service.request(email=user.email)

    stored_token = db_session.scalar(
        select(PasswordResetToken).where(PasswordResetToken.user_id == user.id)
    )

    assert stored_token is not None
    assert stored_token.token_hash == hash_opaque_token(sender.messages[0].reset_token)
    assert stored_token.expires_at == now + timedelta(minutes=30)
    assert stored_token.consumed_at is None
    assert stored_token.invalidated_at is None
    assert sender.messages[0].recipient == user.email


def test_reset_request_invalidates_the_previous_active_token(
    db_session: Session,
) -> None:
    user = UserRepository(db_session).create(
        email="reset-replace@example.com",
        password_hash="example-password-hash",
    )
    sender = RecordingEmailSender()
    now = datetime.now(UTC)
    service = PasswordResetRequestService(
        db_session,
        sender,
        clock=lambda: now,
    )

    service.request(email=user.email)
    service.request(email=user.email)

    tokens = list(
        db_session.scalars(
            select(PasswordResetToken)
            .where(PasswordResetToken.user_id == user.id)
            .order_by(PasswordResetToken.created_at)
        )
    )

    assert len(tokens) == 2
    assert tokens[0].invalidated_at == now
    assert tokens[1].invalidated_at is None


def test_reset_request_does_not_reveal_unknown_email(
    db_session: Session,
) -> None:
    sender = RecordingEmailSender()
    service = PasswordResetRequestService(db_session, sender)

    service.request(email=f"missing-{uuid4()}@example.com")

    assert sender.messages == []
