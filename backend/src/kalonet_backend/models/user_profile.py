from datetime import date
from decimal import Decimal
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class UserProfile(TimestampMixin, Base):
    """Health and goal information collected during onboarding."""

    __tablename__ = "user_profiles"
    __table_args__ = (
        CheckConstraint(
            "sex_for_formula IS NULL OR sex_for_formula IN ('male', 'female')",
            name="sex_for_formula_allowed",
        ),
        CheckConstraint(
            "height_cm IS NULL OR height_cm BETWEEN 120.00 AND 230.00",
            name="height_cm_range",
        ),
        CheckConstraint(
            "weight_kg IS NULL OR weight_kg BETWEEN 35.00 AND 300.00",
            name="weight_kg_range",
        ),
        CheckConstraint(
            ("goal IS NULL OR goal IN ('weight_loss', 'maintain_weight', 'weight_gain')"),
            name="goal_allowed",
        ),
        CheckConstraint(
            (
                "activity_level IS NULL OR activity_level IN "
                "('sedentary', 'lightly_active', "
                "'moderately_active', 'very_active')"
            ),
            name="activity_level_allowed",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
            name="fk_user_profiles_user_id_users",
        ),
        primary_key=True,
    )

    date_of_birth: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    sex_for_formula: Mapped[str | None] = mapped_column(
        String(10),
        nullable=True,
    )

    height_cm: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2),
        nullable=True,
    )

    weight_kg: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 2),
        nullable=True,
    )

    goal: Mapped[str | None] = mapped_column(
        String(30),
        nullable=True,
    )

    activity_level: Mapped[str | None] = mapped_column(
        String(30),
        nullable=True,
    )
