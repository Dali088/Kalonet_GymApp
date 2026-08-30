from datetime import time
from uuid import UUID, uuid4

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from kalonet_backend.models import (
    DietaryPreference,
    MealScheduleItem,
    UserDietaryPreference,
    UserProfile,
)


class PersonalizationRepository:
    """Database operations for onboarding personalization data."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get_profile(self, user_id: UUID, *, for_update: bool = False) -> UserProfile | None:
        statement = select(UserProfile).where(UserProfile.user_id == user_id)
        if for_update:
            statement = statement.with_for_update()
        return self._session.scalar(statement)

    def get_or_create_profile(self, user_id: UUID) -> UserProfile:
        profile = self.get_profile(user_id, for_update=True)
        if profile is not None:
            return profile

        profile = UserProfile(user_id=user_id)
        self._session.add(profile)
        self._session.flush()
        return profile

    def update_profile(self, profile: UserProfile, **values: object) -> UserProfile:
        for field, value in values.items():
            if value is not None:
                setattr(profile, field, value)
        self._session.flush()
        return profile

    def set_nickname(self, profile: UserProfile, nickname: str | None) -> UserProfile:
        """Assign the nickname explicitly so ``None`` means clear, not skip."""

        profile.nickname = nickname
        self._session.flush()
        return profile

    def list_preference_codes(self, user_id: UUID) -> list[str]:
        statement = (
            select(DietaryPreference.code)
            .join(
                UserDietaryPreference,
                UserDietaryPreference.dietary_preference_id == DietaryPreference.id,
            )
            .where(UserDietaryPreference.user_id == user_id)
            .order_by(DietaryPreference.code)
        )
        return list(self._session.scalars(statement))

    def get_active_preferences(self, codes: list[str]) -> list[DietaryPreference]:
        if not codes:
            return []
        statement = select(DietaryPreference).where(
            DietaryPreference.code.in_(codes),
            DietaryPreference.is_active.is_(True),
        )
        return list(self._session.scalars(statement))

    def replace_preferences(self, user_id: UUID, preference_ids: list[UUID]) -> None:
        self._session.execute(
            delete(UserDietaryPreference).where(UserDietaryPreference.user_id == user_id)
        )
        self._session.flush()
        self._session.add_all(
            [
                UserDietaryPreference(
                    user_id=user_id,
                    dietary_preference_id=preference_id,
                )
                for preference_id in preference_ids
            ]
        )
        self._session.flush()

    def list_schedule(self, user_id: UUID) -> list[MealScheduleItem]:
        statement = (
            select(MealScheduleItem)
            .where(MealScheduleItem.user_id == user_id)
            .order_by(MealScheduleItem.display_order)
        )
        return list(self._session.scalars(statement))

    def replace_schedule(
        self,
        user_id: UUID,
        items: list[tuple[time, int]],
    ) -> list[MealScheduleItem]:
        self._session.execute(delete(MealScheduleItem).where(MealScheduleItem.user_id == user_id))
        self._session.flush()
        rows = [
            MealScheduleItem(
                id=uuid4(),
                user_id=user_id,
                preferred_time=preferred_time,
                display_order=display_order,
            )
            for preferred_time, display_order in items
        ]
        self._session.add_all(rows)
        self._session.flush()
        return rows
