"""create personalization tables

Revision ID: d6e7f8a9b0c1
Revises: f4c9a1d2e7b8
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d6e7f8a9b0c1"
down_revision: str | Sequence[str] | None = "f4c9a1d2e7b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


SEED_PREFERENCES = (
    ("6f77d1f0-4f79-4cb0-8ad8-000000000001", "halal", "Halal"),
    ("6f77d1f0-4f79-4cb0-8ad8-000000000002", "vegetarian", "Vegetarian"),
    ("6f77d1f0-4f79-4cb0-8ad8-000000000003", "vegan", "Vegan"),
    ("6f77d1f0-4f79-4cb0-8ad8-000000000004", "gluten_free", "Gluten-free"),
    ("6f77d1f0-4f79-4cb0-8ad8-000000000005", "lactose_free", "Lactose-free"),
    ("6f77d1f0-4f79-4cb0-8ad8-000000000006", "pescatarian", "Pescatarian"),
)


def upgrade() -> None:
    """Create normalized personalization storage and seed definitions."""
    op.create_table(
        "dietary_preferences",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
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
        sa.PrimaryKeyConstraint("id", name=op.f("pk_dietary_preferences")),
        sa.UniqueConstraint("code", name=op.f("uq_dietary_preferences_code")),
    )
    op.create_table(
        "user_dietary_preferences",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("dietary_preference_id", sa.Uuid(), nullable=False),
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
        sa.ForeignKeyConstraint(
            ["dietary_preference_id"],
            ["dietary_preferences.id"],
            name="fk_user_dietary_preferences_preference_id_dietary_preferences",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_user_dietary_preferences_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "user_id", "dietary_preference_id", name=op.f("pk_user_dietary_preferences")
        ),
    )
    op.create_index(
        "ix_user_dietary_preferences_dietary_preference_id",
        "user_dietary_preferences",
        ["dietary_preference_id"],
    )
    op.create_table(
        "meal_schedule_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("meal_type", sa.String(length=20), nullable=False),
        sa.Column("preferred_time", sa.Time(), nullable=False),
        sa.Column("display_order", sa.SmallInteger(), nullable=False),
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
        sa.CheckConstraint(
            "display_order BETWEEN 1 AND 20",
            name=op.f("ck_meal_schedule_items_display_order_range"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_meal_schedule_items_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_meal_schedule_items")),
        sa.UniqueConstraint(
            "user_id", "display_order", name=op.f("uq_meal_schedule_items_user_display_order")
        ),
        sa.UniqueConstraint(
            "user_id", "meal_type", name=op.f("uq_meal_schedule_items_user_meal_type")
        ),
    )
    op.create_index("ix_meal_schedule_items_user_id", "meal_schedule_items", ["user_id"])
    op.bulk_insert(
        sa.table(
            "dietary_preferences",
            sa.column("id", sa.Uuid()),
            sa.column("code", sa.String()),
            sa.column("display_name", sa.String()),
            sa.column("is_active", sa.Boolean()),
        ),
        [
            {"id": identifier, "code": code, "display_name": name, "is_active": True}
            for identifier, code, name in SEED_PREFERENCES
        ],
    )


def downgrade() -> None:
    """Drop personalization storage and its seeded definitions."""
    op.drop_index("ix_meal_schedule_items_user_id", table_name="meal_schedule_items")
    op.drop_table("meal_schedule_items")
    op.drop_index(
        "ix_user_dietary_preferences_dietary_preference_id",
        table_name="user_dietary_preferences",
    )
    op.drop_table("user_dietary_preferences")
    op.drop_table("dietary_preferences")
