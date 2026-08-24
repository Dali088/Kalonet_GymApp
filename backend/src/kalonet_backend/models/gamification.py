from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class UserProgression(TimestampMixin, Base):
    """One server-authoritative XP total per user."""

    __tablename__ = "user_progression"
    __table_args__ = (
        CheckConstraint("total_xp >= 0", name="ck_user_progression_total_xp_nonnegative"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_user_progression_user_id_users"),
        primary_key=True,
    )
    total_xp: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")


class XpAward(TimestampMixin, Base):
    """Append-only evidence for one XP award per user/reason/period."""

    __tablename__ = "xp_awards"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_xp_awards_amount_positive"),
        UniqueConstraint(
            "user_id",
            "reason_code",
            "period_key",
            name="uq_xp_awards_user_reason_period",
        ),
        Index("ix_xp_awards_user_id", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_xp_awards_user_id_users"),
        nullable=False,
    )
    reason_code: Mapped[str] = mapped_column(String(64), nullable=False)
    period_key: Mapped[str] = mapped_column(String(32), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)


class UserBadge(TimestampMixin, Base):
    """One durable unlock record for a static badge definition."""

    __tablename__ = "user_badges"
    __table_args__ = (
        UniqueConstraint("user_id", "badge_code", name="uq_user_badges_user_badge"),
        Index("ix_user_badges_user_id", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_user_badges_user_id_users"),
        nullable=False,
    )
    badge_code: Mapped[str] = mapped_column(String(64), nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default="now()"
    )
