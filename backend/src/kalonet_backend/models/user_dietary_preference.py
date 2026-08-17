from uuid import UUID

from sqlalchemy import ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from kalonet_backend.db.base import Base
from kalonet_backend.db.mixins import TimestampMixin


class UserDietaryPreference(TimestampMixin, Base):
    """Normalized junction row connecting a user to a shared preference."""

    __tablename__ = "user_dietary_preferences"
    __table_args__ = (
        Index("ix_user_dietary_preferences_dietary_preference_id", "dietary_preference_id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
            name="fk_user_dietary_preferences_user_id_users",
        ),
        primary_key=True,
    )
    dietary_preference_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "dietary_preferences.id",
            ondelete="RESTRICT",
            name="fk_user_dietary_preferences_preference_id_dietary_preferences",
        ),
        primary_key=True,
    )
