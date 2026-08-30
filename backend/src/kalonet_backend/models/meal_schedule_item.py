from datetime import time
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, ForeignKey, Index, SmallInteger, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class MealScheduleItem(TimestampMixin, Base):
    """User-owned scheduled meal time and display position."""

    __tablename__ = "meal_schedule_items"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "display_order",
            name="uq_meal_schedule_items_user_display_order",
        ),
        CheckConstraint("display_order BETWEEN 1 AND 15", name="display_order_range"),
        Index("ix_meal_schedule_items_user_id", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_meal_schedule_items_user_id_users"),
        nullable=False,
    )
    preferred_time: Mapped[time] = mapped_column(Time, nullable=False)
    display_order: Mapped[int] = mapped_column(SmallInteger, nullable=False)
