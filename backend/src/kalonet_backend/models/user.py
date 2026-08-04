from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class User(TimestampMixin, Base):
    """Registered Kalonet account."""

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "email = lower(btrim(email))",
            name="email_normalized",
        ),
        CheckConstraint(
            "length(email) > 3",
            name="email_minimum_length",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    email: Mapped[str] = mapped_column(
        String(320),
        nullable=False,
        unique=True,
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    onboarding_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
