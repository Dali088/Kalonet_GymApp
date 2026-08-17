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
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class Meal(TimestampMixin, Base):
    """One user-owned eating occasion containing one or more food snapshots."""

    __tablename__ = "meals"
    __table_args__ = (
        CheckConstraint(
            "meal_type IN ('breakfast', 'morning_snack', 'lunch', 'afternoon_snack', "
            "'dinner', 'evening_snack')",
            name="meal_type_allowed",
        ),
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 100", name="name_not_blank"),
        Index("ix_meals_user_date_recorded_at", "user_id", "record_date", "recorded_at", "id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_meals_user_id_users"),
        nullable=False,
    )
    record_date: Mapped[date] = mapped_column(Date, nullable=False)
    meal_type: Mapped[str] = mapped_column(String(30), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    items: Mapped[list["MealItem"]] = relationship(
        back_populates="meal", cascade="all, delete-orphan", order_by="MealItem.display_order"
    )


class MealItem(TimestampMixin, Base):
    """An accepted nutrition snapshot stored inside a meal."""

    __tablename__ = "meal_items"
    __table_args__ = (
        CheckConstraint("source IN ('manual', 'barcode')", name="source_allowed"),
        CheckConstraint("quantity > 0", name="quantity_positive"),
        CheckConstraint(
            "calories_kcal >= 0 AND protein_g >= 0 AND carbohydrate_g >= 0 AND fat_g >= 0",
            name="nutrition_nonnegative",
        ),
        CheckConstraint(
            "source = 'manual' OR (source_provider IS NOT NULL AND source_barcode IS NOT NULL)",
            name="barcode_source_metadata",
        ),
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        UniqueConstraint("meal_id", "display_order", name="uq_meal_items_display_order"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    meal_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("meals.id", ondelete="CASCADE", name="fk_meal_items_meal_id_meals"),
        nullable=False,
    )
    display_order: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    source: Mapped[str] = mapped_column(String(20), nullable=False, default="manual")
    source_provider: Mapped[str | None] = mapped_column(String(64), nullable=True)
    source_api_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    source_barcode: Mapped[str | None] = mapped_column(String(32), nullable=True)
    source_retrieved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(10, 3), nullable=False)
    serving_description: Mapped[str] = mapped_column(String(160), nullable=False)
    calories_kcal: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    protein_g: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    carbohydrate_g: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    fat_g: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    meal: Mapped[Meal] = relationship(back_populates="items")
