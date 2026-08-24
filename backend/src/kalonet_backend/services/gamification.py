from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.core.gamification import (
    BADGES,
    DAILY_QUESTS,
    DEFAULT_STEP_TARGET,
    DEFAULT_WATER_TARGET_ML,
    WEEKLY_QUESTS,
    QuestDefinition,
    next_rank_for_xp,
    rank_for_xp,
)
from kalonet_backend.models import User
from kalonet_backend.repositories.gamification import GamificationRepository
from kalonet_backend.schemas.gamification import (
    BadgeProgressResponse,
    GamificationSummaryResponse,
    LeaderboardEntryResponse,
    LeaderboardResponse,
    QuestProgressResponse,
)


class GamificationOnboardingRequiredError(ValueError):
    """Gamification is available only after onboarding has completed."""


class GamificationService:
    """Evaluate authoritative tracking state and persist idempotent rewards."""

    def __init__(self, session: Session) -> None:
        self.session = session
        self.repository = GamificationRepository(session)

    def evaluate_after_tracking(self, user_id: UUID, record_date: date) -> None:
        """Award newly completed periods without committing the caller's transaction."""

        user = self.session.scalar(select(User).where(User.id == user_id))
        if user is None or user.onboarding_completed_at is None:
            return
        self.repository.ensure_progression(user_id)
        self._evaluate_daily(user_id, record_date)
        self._evaluate_weekly(user_id, record_date)
        self._evaluate_badges(user_id)

    def get_summary(self, user_id: UUID, record_date: date) -> GamificationSummaryResponse:
        """Build a date-scoped summary without awarding historical activity."""

        try:
            self._require_completed_user(user_id)
            self.repository.ensure_progression(user_id)
            self.session.commit()
            progression = self.repository.progression(user_id)
            daily = self._daily_quests(user_id, record_date)
            weekly = self._weekly_quests(user_id, record_date)
            badges = self._badges(user_id)
            position, size = self.repository.leaderboard_position(user_id)
            return self._summary(progression.total_xp, daily, weekly, badges, position, size)
        except Exception:
            self.session.rollback()
            raise

    def get_leaderboard(self, user_id: UUID, limit: int, offset: int) -> LeaderboardResponse:
        self._require_completed_user(user_id)
        rows, total = self.repository.leaderboard_rows(limit, offset)
        entries = [
            LeaderboardEntryResponse(
                position=position,
                display_name=nickname or "Kalonet member",
                total_xp=total_xp,
                rank=rank_for_xp(total_xp).code,
                is_current_user=leaderboard_user_id == user_id,
            )
            for leaderboard_user_id, nickname, total_xp, position in rows
        ]
        return LeaderboardResponse(
            items=entries,
            limit=limit,
            offset=offset,
            returned=len(entries),
            total=total,
        )

    def _require_completed_user(self, user_id: UUID) -> None:
        user = self.session.scalar(select(User).where(User.id == user_id))
        if user is None or user.onboarding_completed_at is None:
            raise GamificationOnboardingRequiredError

    def _evaluate_daily(self, user_id: UUID, record_date: date) -> None:
        metrics = self.repository.daily_metrics(user_id, record_date)
        values = (metrics[0], metrics[1], metrics[2], metrics[3])
        period_key = record_date.isoformat()
        for definition, current in zip(DAILY_QUESTS, values, strict=True):
            if current >= definition.target:
                self.repository.award_xp(user_id, definition.code, period_key, definition.reward_xp)

    def _evaluate_weekly(self, user_id: UUID, record_date: date) -> None:
        start = record_date - timedelta(days=record_date.weekday())
        end = start + timedelta(days=6)
        metrics = self.repository.weekly_metrics(
            user_id, start, end, DEFAULT_WATER_TARGET_ML, DEFAULT_STEP_TARGET
        )
        period_key = f"{start.isoformat()}:{end.isoformat()}"
        for definition, current in zip(WEEKLY_QUESTS, metrics, strict=True):
            if current >= definition.target:
                self.repository.award_xp(user_id, definition.code, period_key, definition.reward_xp)

    def _evaluate_badges(self, user_id: UUID) -> None:
        metrics = self.repository.history_metrics(
            user_id, DEFAULT_WATER_TARGET_ML, DEFAULT_STEP_TARGET
        )
        (
            first_meal,
            first_water,
            first_steps,
            first_activity,
            meal_days,
            hydration_days,
            step_days,
            activity_days,
        ) = metrics
        rank_code = rank_for_xp(self.repository.progression(user_id).total_xp).code
        conditions = {
            "FIRST_MEAL": first_meal,
            "FIRST_HYDRATION_GOAL": first_water and hydration_days >= 1,
            "FIRST_STEP_GOAL": first_steps,
            "FIRST_ACTIVITY": first_activity,
            "MEAL_7_DAYS": meal_days >= 7,
            "HYDRATION_7_DAYS": hydration_days >= 7,
            "STEPS_7_DAYS": step_days >= 7,
            "ACTIVITY_5_DAYS": activity_days >= 5,
            "RANK_D": rank_code in {"D", "C", "B", "A", "S"},
            "RANK_C": rank_code in {"C", "B", "A", "S"},
            "RANK_B": rank_code in {"B", "A", "S"},
            "RANK_A": rank_code in {"A", "S"},
            "RANK_S": rank_code == "S",
        }
        for definition in BADGES:
            if conditions[definition.code]:
                self.repository.unlock_badge(user_id, definition.code)

    def _daily_quests(self, user_id: UUID, record_date: date) -> list[QuestProgressResponse]:
        metrics = self.repository.daily_metrics(user_id, record_date)
        period_key = record_date.isoformat()
        awarded = self.repository.awarded_codes(user_id, period_key)
        return [
            self._quest_response(definition, current, period_key, definition.code in awarded)
            for definition, current in zip(DAILY_QUESTS, metrics, strict=True)
        ]

    def _weekly_quests(self, user_id: UUID, record_date: date) -> list[QuestProgressResponse]:
        start = record_date - timedelta(days=record_date.weekday())
        end = start + timedelta(days=6)
        metrics = self.repository.weekly_metrics(
            user_id, start, end, DEFAULT_WATER_TARGET_ML, DEFAULT_STEP_TARGET
        )
        period_key = f"{start.isoformat()}:{end.isoformat()}"
        awarded = self.repository.awarded_codes(user_id, period_key)
        return [
            self._quest_response(definition, current, period_key, definition.code in awarded)
            for definition, current in zip(WEEKLY_QUESTS, metrics, strict=True)
        ]

    @staticmethod
    def _quest_response(
        definition: QuestDefinition, current: int, period_key: str, awarded: bool
    ) -> QuestProgressResponse:
        return QuestProgressResponse(
            code=definition.code,
            title=definition.title,
            description=definition.description,
            period=definition.period,  # type: ignore[arg-type]
            period_key=period_key,
            current=current,
            target=definition.target,
            reward_xp=definition.reward_xp,
            completed=current >= definition.target,
            awarded=awarded,
        )

    def _badges(self, user_id: UUID) -> list[BadgeProgressResponse]:
        unlocked = self.repository.unlocked_badges(user_id)
        return [
            BadgeProgressResponse(
                code=definition.code,
                title=definition.title,
                description=definition.description,
                category=definition.category,  # type: ignore[arg-type]
                unlocked=definition.code in unlocked,
                unlocked_at=unlocked.get(definition.code),  # type: ignore[arg-type]
            )
            for definition in BADGES
        ]

    @staticmethod
    def _summary(
        total_xp: int,
        daily: list[QuestProgressResponse],
        weekly: list[QuestProgressResponse],
        badges: list[BadgeProgressResponse],
        position: int,
        size: int,
    ) -> GamificationSummaryResponse:
        current = rank_for_xp(total_xp)
        next_rank = next_rank_for_xp(total_xp)
        return GamificationSummaryResponse(
            total_xp=total_xp,
            rank=current.code,
            next_rank=next_rank.code if next_rank else None,
            xp_to_next_rank=max(0, next_rank.minimum_xp - total_xp) if next_rank else 0,
            daily_quests=daily,
            weekly_quests=weekly,
            badges=badges,
            unlocked_badge_count=sum(1 for badge in badges if badge.unlocked),
            total_badge_count=len(badges),
            leaderboard_position=position,
            leaderboard_size=size,
        )
