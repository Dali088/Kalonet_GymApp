from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from kalonet_backend.models import UserSettings
from kalonet_backend.repositories import UserRepository, UserSettingsRepository
from kalonet_backend.services.onboarding import UserNotFoundError


class InvalidTimeZoneError(ValueError):
    """Raised when a settings update contains an unknown IANA time zone."""


class SettingsService:
    """Coordinate user-settings reads, validation, and transaction boundaries."""

    def __init__(self, session: Session) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._settings = UserSettingsRepository(session)

    def get(self, user_id: UUID) -> UserSettings:
        """Return settings, creating the default row for legacy users if needed."""
        try:
            if self._users.get_by_id(user_id) is None:
                raise UserNotFoundError
            settings = self._settings.get(user_id)
            if settings is None:
                settings = self._settings.get_or_create(user_id)
                self._session.commit()
            return settings
        except Exception:
            self._session.rollback()
            raise

    def update(
        self,
        user_id: UUID,
        *,
        measurement_system: str | None,
        time_zone: str | None,
        theme_preference: str | None,
    ) -> UserSettings:
        """Validate and persist a partial settings update atomically."""
        try:
            if self._users.get_by_id(user_id) is None:
                raise UserNotFoundError
            if time_zone is not None:
                try:
                    ZoneInfo(time_zone)
                except (ZoneInfoNotFoundError, ValueError) as exception:
                    raise InvalidTimeZoneError from exception

            settings = self._settings.get_or_create(user_id)
            if measurement_system is not None:
                settings.measurement_system = measurement_system
            if time_zone is not None:
                settings.time_zone = time_zone
            if theme_preference is not None:
                settings.theme_preference = theme_preference
            self._session.commit()
            return settings
        except Exception:
            self._session.rollback()
            raise
