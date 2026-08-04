from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class UserSettings(TimestampMixin, Base):
    """Application preferences belonging to one user."""

    __tablename__ = "user_settings"
    __table_args__ = (
        CheckConstraint(
            "measurement_system IN ('metric', 'imperial')",
            name="measurement_system_allowed",
        ),
        CheckConstraint(
            "theme_preference IN ('system', 'light', 'dark')",
            name="theme_preference_allowed",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
            name="fk_user_settings_user_id_users",
        ),
        primary_key=True,
    )

    measurement_system: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="metric",
        server_default="metric",
    )

    time_zone: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="UTC",
        server_default="UTC",
    )

    theme_preference: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="system",
        server_default="system",
    )
