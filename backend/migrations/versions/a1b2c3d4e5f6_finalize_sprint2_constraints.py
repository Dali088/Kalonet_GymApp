"""finalize Sprint 2 controlled-value constraints

Revision ID: a1b2c3d4e5f6
Revises: f5a6b7c8d9e0
"""

from collections.abc import Sequence

from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: str | Sequence[str] | None = "f5a6b7c8d9e0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add database-enforced controlled-value constraints for Sprint 2 tables."""
    op.execute(
        "ALTER TABLE meal_schedule_items ADD CONSTRAINT "
        "ck_meal_schedule_items_meal_type_allowed CHECK "
        "(meal_type IN ('breakfast', 'morning_snack', 'lunch', "
        "'afternoon_snack', 'dinner', 'evening_snack'))"
    )
    op.execute(
        "ALTER TABLE nutrition_targets ADD CONSTRAINT "
        "ck_nutrition_targets_goal_allowed CHECK "
        "(goal IN ('weight_loss', 'maintain_weight', 'weight_gain'))"
    )
    op.execute(
        "ALTER TABLE nutrition_targets ADD CONSTRAINT "
        "ck_nutrition_targets_sex_for_formula_allowed CHECK "
        "(sex_for_formula IN ('male', 'female'))"
    )
    op.execute(
        "ALTER TABLE nutrition_targets ADD CONSTRAINT "
        "ck_nutrition_targets_activity_level_allowed CHECK "
        "(activity_level IN ('sedentary', 'lightly_active', "
        "'moderately_active', 'very_active'))"
    )


def downgrade() -> None:
    """Remove the Sprint 2 controlled-value constraints."""
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS "
        "ck_nutrition_targets_activity_level_allowed"
    )
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS "
        "ck_nutrition_targets_ck_nutrition_targets_activity_leve_fd65"
    )
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS "
        "ck_nutrition_targets_sex_for_formula_allowed"
    )
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS "
        "ck_nutrition_targets_ck_nutrition_targets_sex_for_formu_fda1"
    )
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS ck_nutrition_targets_goal_allowed"
    )
    op.execute(
        "ALTER TABLE nutrition_targets DROP CONSTRAINT IF EXISTS "
        "ck_nutrition_targets_ck_nutrition_targets_goal_allowed"
    )
    op.execute(
        "ALTER TABLE meal_schedule_items DROP CONSTRAINT IF EXISTS "
        "ck_meal_schedule_items_meal_type_allowed"
    )
    op.execute(
        "ALTER TABLE meal_schedule_items DROP CONSTRAINT IF EXISTS "
        "ck_meal_schedule_items_ck_meal_schedule_items_meal_type_allowed"
    )
