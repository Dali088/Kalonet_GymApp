"""reconcile authentication constraint names

Revision ID: f5a6b7c8d9e0
Revises: e7f8a9b0c1d2
"""

from collections.abc import Sequence

from alembic import op

revision: str = "f5a6b7c8d9e0"
down_revision: str | Sequence[str] | None = "e7f8a9b0c1d2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


OLD_TO_NEW = {
    "ck_refresh_sessions_ck_refresh_sessions_rotated_after_creation": (
        "ck_refresh_sessions_rotated_after_creation"
    ),
    "ck_refresh_sessions_ck_refresh_sessions_revoked_after_creation": (
        "ck_refresh_sessions_revoked_after_creation"
    ),
    "ck_refresh_sessions_ck_refresh_sessions_revocation_reas_c3f9": (
        "ck_refresh_sessions_revocation_reason_consistency"
    ),
}


def upgrade() -> None:
    """Rename constraints created with the old naming-convention interaction."""
    for old_name, new_name in OLD_TO_NEW.items():
        op.execute(f'ALTER TABLE refresh_sessions RENAME CONSTRAINT "{old_name}" TO "{new_name}"')


def downgrade() -> None:
    """Restore the historical names for a reversible development downgrade."""
    for old_name, new_name in OLD_TO_NEW.items():
        op.execute(f'ALTER TABLE refresh_sessions RENAME CONSTRAINT "{new_name}" TO "{old_name}"')
