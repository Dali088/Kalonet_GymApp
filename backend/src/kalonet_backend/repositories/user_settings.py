from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import UserSettings


class UserSettingsRepository:
    """Persistence operations for one user's application settings."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get(self, user_id: UUID) -> UserSettings | None:
        return self._session.scalar(select(UserSettings).where(UserSettings.user_id == user_id))

    def get_or_create(self, user_id: UUID) -> UserSettings:
        settings = self.get(user_id)
        if settings is not None:
            return settings

        settings = UserSettings(user_id=user_id)
        self._session.add(settings)
        self._session.flush()
        return settings
