"""create Sprint 3 tracking and retry-safety tables

Revision ID: b7c8d9e0f1a2
Revises: a1b2c3d4e5f6
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "b7c8d9e0f1a2"
down_revision: str | Sequence[str] | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the six approved Sprint 3 tables and their access-path indexes."""
    op.create_table(
        "meals",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("record_date", sa.Date(), nullable=False),
        sa.Column("meal_type", sa.String(length=30), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "meal_type IN ('breakfast', 'morning_snack', 'lunch', 'afternoon_snack', "
            "'dinner', 'evening_snack')",
            name=op.f("ck_meals_meal_type_allowed"),
        ),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 100", name=op.f("ck_meals_name_not_blank")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_meals_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_meals"),
    )
    op.create_index(
        "ix_meals_user_date_recorded_at", "meals", ["user_id", "record_date", "recorded_at", "id"]
    )

    op.create_table(
        "meal_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("meal_id", sa.Uuid(), nullable=False),
        sa.Column("display_order", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("source", sa.String(length=20), nullable=False),
        sa.Column("source_provider", sa.String(length=64), nullable=True),
        sa.Column("source_api_version", sa.String(length=32), nullable=True),
        sa.Column("source_barcode", sa.String(length=32), nullable=True),
        sa.Column("source_retrieved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("quantity", sa.Numeric(precision=10, scale=3), nullable=False),
        sa.Column("serving_description", sa.String(length=160), nullable=False),
        sa.Column("calories_kcal", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("protein_g", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("carbohydrate_g", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("fat_g", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "source IN ('manual', 'barcode')", name=op.f("ck_meal_items_source_allowed")
        ),
        sa.CheckConstraint("quantity > 0", name=op.f("ck_meal_items_quantity_positive")),
        sa.CheckConstraint(
            "calories_kcal >= 0 AND protein_g >= 0 AND carbohydrate_g >= 0 AND fat_g >= 0",
            name=op.f("ck_meal_items_nutrition_nonnegative"),
        ),
        sa.CheckConstraint(
            "source = 'manual' OR (source_provider IS NOT NULL AND source_barcode IS NOT NULL)",
            name=op.f("ck_meal_items_barcode_source_metadata"),
        ),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160", name=op.f("ck_meal_items_name_not_blank")
        ),
        sa.ForeignKeyConstraint(
            ["meal_id"], ["meals.id"], name="fk_meal_items_meal_id_meals", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_meal_items"),
        sa.UniqueConstraint("meal_id", "display_order", name="uq_meal_items_display_order"),
    )

    op.create_table(
        "water_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("record_date", sa.Date(), nullable=False),
        sa.Column("amount_ml", sa.Integer(), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "amount_ml BETWEEN 1 AND 10000", name=op.f("ck_water_entries_amount_range")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_water_entries_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_water_entries"),
    )
    op.create_index(
        "ix_water_entries_user_date_recorded_at",
        "water_entries",
        ["user_id", "record_date", "recorded_at", "id"],
    )

    op.create_table(
        "daily_step_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("record_date", sa.Date(), nullable=False),
        sa.Column("step_count", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(length=20), server_default="manual", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "step_count BETWEEN 0 AND 200000", name=op.f("ck_daily_step_records_step_count_range")
        ),
        sa.CheckConstraint("source = 'manual'", name=op.f("ck_daily_step_records_source_allowed")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_daily_step_records_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_daily_step_records"),
        sa.UniqueConstraint("user_id", "record_date", name="uq_daily_step_records_user_date"),
    )

    op.create_table(
        "activity_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("record_date", sa.Date(), nullable=False),
        sa.Column("activity_type", sa.String(length=30), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column("estimated_calories_kcal", sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "activity_type IN ('walking', 'running', 'cycling', 'strength_training', "
            "'swimming', 'other')",
            name=op.f("ck_activity_entries_activity_type_allowed"),
        ),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 120", name=op.f("ck_activity_entries_name_not_blank")
        ),
        sa.CheckConstraint(
            "duration_minutes BETWEEN 1 AND 1440", name=op.f("ck_activity_entries_duration_range")
        ),
        sa.CheckConstraint(
            "estimated_calories_kcal IS NULL OR estimated_calories_kcal BETWEEN 0 AND 10000",
            name=op.f("ck_activity_entries_calories_range"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_activity_entries_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_activity_entries"),
    )
    op.create_index(
        "ix_activity_entries_user_date_recorded_at",
        "activity_entries",
        ["user_id", "record_date", "recorded_at", "id"],
    )

    op.create_table(
        "idempotency_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("http_method", sa.String(length=10), nullable=False),
        sa.Column("route_pattern", sa.String(length=160), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("state", sa.String(length=20), nullable=False),
        sa.Column("response_status", sa.Integer(), nullable=True),
        sa.Column("response_body", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "http_method IN ('POST')", name=op.f("ck_idempotency_records_method_allowed")
        ),
        sa.CheckConstraint(
            "state IN ('processing', 'completed')",
            name=op.f("ck_idempotency_records_state_allowed"),
        ),
        sa.CheckConstraint(
            "response_status IS NULL OR response_status BETWEEN 200 AND 299",
            name=op.f("ck_idempotency_records_response_status_success"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_idempotency_records_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_idempotency_records"),
        sa.UniqueConstraint(
            "user_id",
            "http_method",
            "route_pattern",
            "idempotency_key",
            name="uq_idempotency_records_request_identity",
        ),
    )
    op.create_index("ix_idempotency_records_expires_at", "idempotency_records", ["expires_at"])


def downgrade() -> None:
    """Drop Sprint 3 tables in dependency order."""
    op.drop_index("ix_idempotency_records_expires_at", table_name="idempotency_records")
    op.drop_table("idempotency_records")
    op.drop_index("ix_activity_entries_user_date_recorded_at", table_name="activity_entries")
    op.drop_table("activity_entries")
    op.drop_table("daily_step_records")
    op.drop_index("ix_water_entries_user_date_recorded_at", table_name="water_entries")
    op.drop_table("water_entries")
    op.drop_table("meal_items")
    op.drop_index("ix_meals_user_date_recorded_at", table_name="meals")
    op.drop_table("meals")
