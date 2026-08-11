"""reconcile authentication lifecycle fields

Revision ID: f4c9a1d2e7b8
Revises: 3b008487b65b
Create Date: 2026-08-11 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4c9a1d2e7b8"
down_revision: str | Sequence[str] | None = "3b008487b65b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add the approved authentication lifecycle fields and constraints."""

    op.drop_constraint(
        "fk_refresh_sessions_replaced_by_session_id_refresh_sessions",
        "refresh_sessions",
        type_="foreignkey",
    )
    op.drop_column("refresh_sessions", "replaced_by_session_id")

    op.alter_column(
        "refresh_sessions",
        "token_hash",
        existing_type=sa.String(length=255),
        type_=sa.CHAR(length=64),
        existing_nullable=False,
    )
    op.add_column(
        "refresh_sessions",
        sa.Column("rotated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "refresh_sessions",
        sa.Column("revocation_reason", sa.String(length=40), nullable=True),
    )
    op.create_check_constraint(
        "ck_refresh_sessions_rotated_after_creation",
        "refresh_sessions",
        "rotated_at IS NULL OR rotated_at >= created_at",
    )
    op.create_check_constraint(
        "ck_refresh_sessions_revoked_after_creation",
        "refresh_sessions",
        "revoked_at IS NULL OR revoked_at >= created_at",
    )
    op.create_check_constraint(
        "ck_refresh_sessions_revocation_reason_consistency",
        "refresh_sessions",
        "(revoked_at IS NULL AND revocation_reason IS NULL) "
        "OR (revoked_at IS NOT NULL AND revocation_reason IS NOT NULL)",
    )

    op.alter_column(
        "password_reset_tokens",
        "token_hash",
        existing_type=sa.String(length=255),
        type_=sa.CHAR(length=64),
        existing_nullable=False,
    )
    op.alter_column(
        "password_reset_tokens",
        "used_at",
        new_column_name="consumed_at",
        existing_type=sa.DateTime(timezone=True),
        existing_nullable=True,
    )
    op.add_column(
        "password_reset_tokens",
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    """Restore the previous authentication schema shape."""

    op.drop_column("password_reset_tokens", "invalidated_at")
    op.alter_column(
        "password_reset_tokens",
        "consumed_at",
        new_column_name="used_at",
        existing_type=sa.DateTime(timezone=True),
        existing_nullable=True,
    )
    op.alter_column(
        "password_reset_tokens",
        "token_hash",
        existing_type=sa.CHAR(length=64),
        type_=sa.String(length=255),
        existing_nullable=False,
    )

    op.drop_constraint(
        "ck_refresh_sessions_revocation_reason_consistency",
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        "ck_refresh_sessions_revoked_after_creation",
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        "ck_refresh_sessions_rotated_after_creation",
        "refresh_sessions",
        type_="check",
    )
    op.drop_column("refresh_sessions", "revocation_reason")
    op.drop_column("refresh_sessions", "rotated_at")
    op.alter_column(
        "refresh_sessions",
        "token_hash",
        existing_type=sa.CHAR(length=64),
        type_=sa.String(length=255),
        existing_nullable=False,
    )
    op.add_column(
        "refresh_sessions",
        sa.Column("replaced_by_session_id", sa.Uuid(), nullable=True),
    )
    op.create_foreign_key(
        "fk_refresh_sessions_replaced_by_session_id_refresh_sessions",
        "refresh_sessions",
        "refresh_sessions",
        ["replaced_by_session_id"],
        ["id"],
        ondelete="SET NULL",
    )
