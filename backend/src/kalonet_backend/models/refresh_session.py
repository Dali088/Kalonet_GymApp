from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CHAR, CheckConstraint, DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class RefreshSession(TimestampMixin, Base):
    """Persisted refresh-token session used for rotation and revocation."""

    __tablename__ = "refresh_sessions"
    __table_args__ = (
        CheckConstraint(
            "expires_at > created_at",
            name="expires_after_creation",
        ),
        CheckConstraint(
            "rotated_at IS NULL OR rotated_at >= created_at",
            name="rotated_after_creation",
        ),
        CheckConstraint(
            "revoked_at IS NULL OR revoked_at >= created_at",
            name="revoked_after_creation",
        ),
        CheckConstraint(
            "(revoked_at IS NULL AND revocation_reason IS NULL) "
            "OR (revoked_at IS NOT NULL AND revocation_reason IS NOT NULL)",
            name="revocation_reason_consistency",
        ),
        Index(
            "ix_refresh_sessions_user_id",
            "user_id",
        ),
        Index(
            "ix_refresh_sessions_family_id",
            "family_id",
        ),
        Index(
            "ix_refresh_sessions_expires_at",
            "expires_at",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
            name="fk_refresh_sessions_user_id_users",
        ),
        nullable=False,
    )

    token_hash: Mapped[str] = mapped_column(
        CHAR(64),
        nullable=False,
        unique=True,
    )

    family_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        nullable=False,
        default=uuid4,
    )

    parent_session_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "refresh_sessions.id",
            ondelete="SET NULL",
            name="fk_refresh_sessions_parent_session_id_refresh_sessions",
        ),
        nullable=True,
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    rotated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    revocation_reason: Mapped[str | None] = mapped_column(
        String(40),
        nullable=True,
    )
