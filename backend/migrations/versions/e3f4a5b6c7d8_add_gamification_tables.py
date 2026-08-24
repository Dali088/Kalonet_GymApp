"""add gamification progression, XP awards, and badge unlocks

Revision ID: e3f4a5b6c7d8
Revises: d2e3f4a5b6c7
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e3f4a5b6c7d8"
down_revision: str | Sequence[str] | None = "d2e3f4a5b6c7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the small server-authoritative gamification persistence boundary."""
    op.create_table(
        "user_progression",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("total_xp", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("total_xp >= 0", name="ck_user_progression_total_xp_nonnegative"),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_user_progression_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("user_id", name="pk_user_progression"),
    )
    op.create_table(
        "xp_awards",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("reason_code", sa.String(length=64), nullable=False),
        sa.Column("period_key", sa.String(length=32), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("amount > 0", name="ck_xp_awards_amount_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_xp_awards_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_xp_awards"),
        sa.UniqueConstraint(
            "user_id", "reason_code", "period_key", name="uq_xp_awards_user_reason_period"
        ),
    )
    op.create_index("ix_xp_awards_user_id", "xp_awards", ["user_id"])
    op.create_table(
        "user_badges",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("badge_code", sa.String(length=64), nullable=False),
        sa.Column(
            "unlocked_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_user_badges_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_user_badges"),
        sa.UniqueConstraint("user_id", "badge_code", name="uq_user_badges_user_badge"),
    )
    op.create_index("ix_user_badges_user_id", "user_badges", ["user_id"])


def downgrade() -> None:
    """Drop gamification tables in reverse dependency order."""
    op.drop_index("ix_user_badges_user_id", table_name="user_badges")
    op.drop_table("user_badges")
    op.drop_index("ix_xp_awards_user_id", table_name="xp_awards")
    op.drop_table("xp_awards")
    op.drop_table("user_progression")
