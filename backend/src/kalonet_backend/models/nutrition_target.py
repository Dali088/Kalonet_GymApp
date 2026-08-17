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
    desc,
)
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class NutritionTarget(TimestampMixin, Base):
    """Immutable nutrition calculation snapshot except for deactivation metadata."""

    __tablename__ = "nutrition_targets"
    __table_args__ = (
        CheckConstraint(
            "goal IN ('weight_loss', 'maintain_weight', 'weight_gain')",
            name="goal_allowed",
        ),
        CheckConstraint(
            "sex_for_formula IN ('male', 'female')",
            name="sex_for_formula_allowed",
        ),
        CheckConstraint(
            "activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active')",
            name="activity_level_allowed",
        ),
        CheckConstraint("age_years BETWEEN 18 AND 65", name="age"),
        CheckConstraint("height_cm BETWEEN 120.00 AND 230.00", name="height"),
        CheckConstraint("weight_kg BETWEEN 35.00 AND 300.00", name="weight"),
        CheckConstraint(
            "activity_multiplier > 0 AND activity_multiplier <= 3.000", name="activity_multiplier"
        ),
        CheckConstraint("bmr_kcal > 0", name="bmr"),
        CheckConstraint("tdee_kcal > 0", name="tdee"),
        CheckConstraint("daily_calories BETWEEN 1000 AND 10000", name="daily_calories"),
        CheckConstraint("protein_g >= 0 AND carbohydrate_g >= 0 AND fat_g >= 0", name="macros"),
        CheckConstraint(
            "deactivated_at IS NULL OR deactivated_at >= created_at", name="deactivation_order"
        ),
        Index(
            "ix_nutrition_targets_user_history",
            "user_id",
            desc("effective_from"),
            desc("created_at"),
        ),
        Index(
            "uq_nutrition_targets_one_active_per_user",
            "user_id",
            unique=True,
            postgresql_where="deactivated_at IS NULL",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE", name="fk_nutrition_targets_user_id_users"),
        nullable=False,
    )
    goal: Mapped[str] = mapped_column(String(30), nullable=False)
    sex_for_formula: Mapped[str] = mapped_column(String(10), nullable=False)
    age_years: Mapped[int] = mapped_column(Integer, nullable=False)
    height_cm: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    weight_kg: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    activity_level: Mapped[str] = mapped_column(String(30), nullable=False)
    activity_multiplier: Mapped[Decimal] = mapped_column(Numeric(5, 3), nullable=False)
    bmr_kcal: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    tdee_kcal: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    goal_adjustment_kcal: Mapped[int] = mapped_column(Integer, nullable=False)
    daily_calories: Mapped[int] = mapped_column(Integer, nullable=False)
    protein_g: Mapped[int] = mapped_column(Integer, nullable=False)
    carbohydrate_g: Mapped[int] = mapped_column(Integer, nullable=False)
    fat_g: Mapped[int] = mapped_column(Integer, nullable=False)
    rule_version: Mapped[str] = mapped_column(String(30), nullable=False)
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)
    deactivated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
