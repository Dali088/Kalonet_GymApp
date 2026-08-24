"""retire barcode meal provenance

Revision ID: c1d2e3f4a5b6
Revises: b7c8d9e0f1a2
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "c1d2e3f4a5b6"
down_revision: str | Sequence[str] | None = "b7c8d9e0f1a2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Keep accepted nutrition snapshots, then remove barcode-only provenance."""
    op.execute(
        """
        UPDATE meal_items
        SET source = 'manual',
            source_provider = NULL,
            source_api_version = NULL,
            source_barcode = NULL,
            source_retrieved_at = NULL
        WHERE source <> 'manual'
           OR source_provider IS NOT NULL
           OR source_api_version IS NOT NULL
           OR source_barcode IS NOT NULL
           OR source_retrieved_at IS NOT NULL
        """
    )
    op.drop_constraint(op.f("ck_meal_items_barcode_source_metadata"), "meal_items", type_="check")
    op.drop_constraint(op.f("ck_meal_items_source_allowed"), "meal_items", type_="check")
    op.drop_column("meal_items", "source_retrieved_at")
    op.drop_column("meal_items", "source_barcode")
    op.drop_column("meal_items", "source_api_version")
    op.drop_column("meal_items", "source_provider")
    op.drop_column("meal_items", "source")


def downgrade() -> None:
    """Restore manual-only provenance columns; retired values cannot be recovered."""
    op.add_column(
        "meal_items",
        sa.Column("source", sa.String(length=20), nullable=False, server_default="manual"),
    )
    op.add_column("meal_items", sa.Column("source_provider", sa.String(length=64), nullable=True))
    op.add_column(
        "meal_items", sa.Column("source_api_version", sa.String(length=32), nullable=True)
    )
    op.add_column("meal_items", sa.Column("source_barcode", sa.String(length=32), nullable=True))
    op.add_column(
        "meal_items",
        sa.Column("source_retrieved_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.alter_column("meal_items", "source", server_default=None)
    op.create_check_constraint(
        op.f("ck_meal_items_source_allowed"), "meal_items", "source = 'manual'"
    )
    op.create_check_constraint(
        op.f("ck_meal_items_barcode_source_metadata"),
        "meal_items",
        "source = 'manual'",
    )
