from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class WaterEntry(TimestampMixin, Base):
    """One correctable amount of water recorded for a local calendar date."""

    __tablename__ = "water_entries"
    __table_args__ = (
        CheckConstraint("amount_ml BETWEEN 1 AND 10000", name="amount_range"),
        Index(
            "ix_water_entries_user_date_recorded_at", "user_id", "record_date", "recorded_at", "id"
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_water_entries_user_id_users"),
        nullable=False,
    )
    record_date: Mapped[date] = mapped_column(Date, nullable=False)
    amount_ml: Mapped[int] = mapped_column(Integer, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class DailyStepRecord(TimestampMixin, Base):
    """One absolute step total per user and local date."""

    __tablename__ = "daily_step_records"
    __table_args__ = (
        CheckConstraint("step_count BETWEEN 0 AND 200000", name="step_count_range"),
        CheckConstraint("source = 'manual'", name="source_allowed"),
        UniqueConstraint("user_id", "record_date", name="uq_daily_step_records_user_date"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_daily_step_records_user_id_users"),
        nullable=False,
    )
    record_date: Mapped[date] = mapped_column(Date, nullable=False)
    step_count: Mapped[int] = mapped_column(Integer, nullable=False)
    source: Mapped[str] = mapped_column(
        String(20), nullable=False, default="manual", server_default="manual"
    )


class ActivityEntry(TimestampMixin, Base):
    """One user-owned activity event for dashboard and history."""

    __tablename__ = "activity_entries"
    __table_args__ = (
        CheckConstraint(
            "activity_type IN ('walking', 'running', 'cycling', 'strength_training', "
            "'swimming', 'other')",
            name="activity_type_allowed",
        ),
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 120", name="name_not_blank"),
        CheckConstraint("duration_minutes BETWEEN 1 AND 1440", name="duration_range"),
        CheckConstraint(
            "estimated_calories_kcal IS NULL OR estimated_calories_kcal BETWEEN 0 AND 10000",
            name="calories_range",
        ),
        Index(
            "ix_activity_entries_user_date_recorded_at",
            "user_id",
            "record_date",
            "recorded_at",
            "id",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_activity_entries_user_id_users"),
        nullable=False,
    )
    record_date: Mapped[date] = mapped_column(Date, nullable=False)
    activity_type: Mapped[str] = mapped_column(String(30), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    estimated_calories_kcal: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class IdempotencyRecord(TimestampMixin, Base):
    """Durable retry state for duplicate-sensitive creation endpoints."""

    __tablename__ = "idempotency_records"
    __table_args__ = (
        CheckConstraint("http_method IN ('POST')", name="method_allowed"),
        CheckConstraint("state IN ('processing', 'completed')", name="state_allowed"),
        CheckConstraint(
            "response_status IS NULL OR response_status BETWEEN 200 AND 299",
            name="response_status_success",
        ),
        UniqueConstraint(
            "user_id",
            "http_method",
            "route_pattern",
            "idempotency_key",
            name="uq_idempotency_records_request_identity",
        ),
        Index("ix_idempotency_records_expires_at", "expires_at"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_idempotency_records_user_id_users"),
        nullable=False,
    )
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    http_method: Mapped[str] = mapped_column(String(10), nullable=False)
    route_pattern: Mapped[str] = mapped_column(String(160), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    state: Mapped[str] = mapped_column(String(20), nullable=False, default="processing")
    response_status: Mapped[int | None] = mapped_column(Integer, nullable=True)
    response_body: Mapped[dict[str, object] | None] = mapped_column(JSONB, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
