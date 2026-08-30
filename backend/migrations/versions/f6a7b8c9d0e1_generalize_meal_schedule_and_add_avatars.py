"""generalize meal schedules and persist profile avatars

Revision ID: f6a7b8c9d0e1
Revises: e3f4a5b6c7d8
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "f6a7b8c9d0e1"
down_revision: str | Sequence[str] | None = "e3f4a5b6c7d8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Preserve schedule times while removing fixed meal-type semantics."""
    op.add_column("user_profiles", sa.Column("avatar_bytes", sa.LargeBinary(), nullable=True))
    op.add_column(
        "user_profiles",
        sa.Column("avatar_content_type", sa.String(length=32), nullable=True),
    )
    op.create_check_constraint(
        op.f("ck_user_profiles_avatar_pair_consistent"),
        "user_profiles",
        "(avatar_bytes IS NULL AND avatar_content_type IS NULL) OR "
        "(avatar_bytes IS NOT NULL AND avatar_content_type IS NOT NULL)",
    )

    # Existing rows already have a user-specific logical order. Temporarily
    # remove the old range check and use negative values so a gapped schedule
    # can be compacted without colliding with the unique order constraint.
    op.execute(
        "ALTER TABLE meal_schedule_items DROP CONSTRAINT IF EXISTS "
        "ck_meal_schedule_items_display_order_range"
    )
    op.execute(
        "ALTER TABLE meal_schedule_items DROP CONSTRAINT IF EXISTS "
        "ck_meal_schedule_items_meal_type_allowed"
    )
    op.execute("UPDATE meal_schedule_items SET display_order = -display_order")
    op.execute(
        """
        WITH ordered AS (
            SELECT id,
                   ROW_NUMBER() OVER (
                       PARTITION BY user_id
                       ORDER BY display_order DESC, preferred_time, id
                   ) AS position
            FROM meal_schedule_items
        )
        UPDATE meal_schedule_items AS items
        SET display_order = ordered.position
        FROM ordered
        WHERE items.id = ordered.id
        """
    )
    op.drop_constraint(
        "uq_meal_schedule_items_user_meal_type",
        "meal_schedule_items",
        type_="unique",
    )
    op.drop_column("meal_schedule_items", "meal_type")
    op.create_check_constraint(
        op.f("ck_meal_schedule_items_display_order_range"),
        "meal_schedule_items",
        "display_order BETWEEN 1 AND 15",
    )


def downgrade() -> None:
    """Restore the former column shape for development-only downgrades."""
    connection = op.get_bind()
    has_unrepresentable_rows = connection.execute(
        sa.text("SELECT 1 FROM meal_schedule_items WHERE display_order > 6 LIMIT 1")
    ).scalar()
    if has_unrepresentable_rows:
        raise RuntimeError(
            "Cannot downgrade a schedule containing more than six meals; "
            "the former fixed meal-type model cannot represent it."
        )
    op.drop_constraint(
        op.f("ck_meal_schedule_items_display_order_range"),
        "meal_schedule_items",
        type_="check",
    )
    op.add_column(
        "meal_schedule_items",
        sa.Column("meal_type", sa.String(length=20), nullable=True),
    )
    op.execute(
        """
        UPDATE meal_schedule_items
        SET meal_type = CASE display_order
            WHEN 1 THEN 'breakfast'
            WHEN 2 THEN 'morning_snack'
            WHEN 3 THEN 'lunch'
            WHEN 4 THEN 'afternoon_snack'
            WHEN 5 THEN 'dinner'
            WHEN 6 THEN 'evening_snack'
            ELSE 'dinner'
        END
        """
    )
    op.alter_column("meal_schedule_items", "meal_type", nullable=False)
    op.create_check_constraint(
        "ck_meal_schedule_items_meal_type_allowed",
        "meal_schedule_items",
        "meal_type IN ('breakfast', 'morning_snack', 'lunch', "
        "'afternoon_snack', 'dinner', 'evening_snack')",
    )
    op.create_unique_constraint(
        "uq_meal_schedule_items_user_meal_type",
        "meal_schedule_items",
        ["user_id", "meal_type"],
    )
    op.create_check_constraint(
        op.f("ck_meal_schedule_items_display_order_range"),
        "meal_schedule_items",
        "display_order BETWEEN 1 AND 20",
    )
    op.drop_constraint(
        op.f("ck_user_profiles_avatar_pair_consistent"),
        "user_profiles",
        type_="check",
    )
    op.drop_column("user_profiles", "avatar_content_type")
    op.drop_column("user_profiles", "avatar_bytes")
