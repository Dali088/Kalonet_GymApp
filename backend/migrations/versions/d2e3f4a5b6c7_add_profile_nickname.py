"""add optional profile nickname

Revision ID: d2e3f4a5b6c7
Revises: c1d2e3f4a5b6
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d2e3f4a5b6c7"
down_revision: str | Sequence[str] | None = "c1d2e3f4a5b6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add a nullable, database-validated privacy display nickname."""
    op.add_column("user_profiles", sa.Column("nickname", sa.String(length=32), nullable=True))
    op.create_check_constraint(
        "ck_user_profiles_nickname_not_blank",
        "user_profiles",
        "nickname IS NULL OR length(btrim(nickname)) BETWEEN 1 AND 32",
    )


def downgrade() -> None:
    """Remove the optional nickname field."""
    op.drop_constraint("ck_user_profiles_nickname_not_blank", "user_profiles", type_="check")
    op.drop_column("user_profiles", "nickname")
