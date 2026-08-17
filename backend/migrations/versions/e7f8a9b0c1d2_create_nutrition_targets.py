"""create nutrition target history

Revision ID: e7f8a9b0c1d2
Revises: d6e7f8a9b0c1
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e7f8a9b0c1d2"
down_revision: str | Sequence[str] | None = "d6e7f8a9b0c1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create immutable nutrition-target snapshots and active-state protection."""
    op.create_table(
        "nutrition_targets",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("goal", sa.String(length=30), nullable=False),
        sa.Column("sex_for_formula", sa.String(length=10), nullable=False),
        sa.Column("age_years", sa.Integer(), nullable=False),
        sa.Column("height_cm", sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column("weight_kg", sa.Numeric(precision=6, scale=2), nullable=False),
        sa.Column("activity_level", sa.String(length=30), nullable=False),
        sa.Column("activity_multiplier", sa.Numeric(precision=5, scale=3), nullable=False),
        sa.Column("bmr_kcal", sa.Numeric(precision=8, scale=2), nullable=False),
        sa.Column("tdee_kcal", sa.Numeric(precision=8, scale=2), nullable=False),
        sa.Column("goal_adjustment_kcal", sa.Integer(), nullable=False),
        sa.Column("daily_calories", sa.Integer(), nullable=False),
        sa.Column("protein_g", sa.Integer(), nullable=False),
        sa.Column("carbohydrate_g", sa.Integer(), nullable=False),
        sa.Column("fat_g", sa.Integer(), nullable=False),
        sa.Column("rule_version", sa.String(length=30), nullable=False),
        sa.Column("effective_from", sa.Date(), nullable=False),
        sa.Column("deactivated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("age_years BETWEEN 18 AND 65", name=op.f("ck_nutrition_targets_age")),
        sa.CheckConstraint(
            "height_cm BETWEEN 120.00 AND 230.00", name=op.f("ck_nutrition_targets_height")
        ),
        sa.CheckConstraint(
            "weight_kg BETWEEN 35.00 AND 300.00", name=op.f("ck_nutrition_targets_weight")
        ),
        sa.CheckConstraint(
            "activity_multiplier > 0 AND activity_multiplier <= 3.000",
            name=op.f("ck_nutrition_targets_activity_multiplier"),
        ),
        sa.CheckConstraint("bmr_kcal > 0", name=op.f("ck_nutrition_targets_bmr")),
        sa.CheckConstraint("tdee_kcal > 0", name=op.f("ck_nutrition_targets_tdee")),
        sa.CheckConstraint(
            "daily_calories BETWEEN 1000 AND 10000",
            name=op.f("ck_nutrition_targets_daily_calories"),
        ),
        sa.CheckConstraint(
            "protein_g >= 0 AND carbohydrate_g >= 0 AND fat_g >= 0",
            name=op.f("ck_nutrition_targets_macros"),
        ),
        sa.CheckConstraint(
            "deactivated_at IS NULL OR deactivated_at >= created_at",
            name=op.f("ck_nutrition_targets_deactivation_order"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_nutrition_targets_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_nutrition_targets")),
    )
    op.create_index(
        "ix_nutrition_targets_user_history",
        "nutrition_targets",
        ["user_id", sa.text("effective_from DESC"), sa.text("created_at DESC")],
    )
    op.create_index(
        "uq_nutrition_targets_one_active_per_user",
        "nutrition_targets",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("deactivated_at IS NULL"),
    )


def downgrade() -> None:
    """Drop nutrition target history."""
    op.drop_index("uq_nutrition_targets_one_active_per_user", table_name="nutrition_targets")
    op.drop_index("ix_nutrition_targets_user_history", table_name="nutrition_targets")
    op.drop_table("nutrition_targets")
