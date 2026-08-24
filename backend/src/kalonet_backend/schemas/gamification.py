from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class QuestProgressResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str
    title: str
    description: str
    period: Literal["daily", "weekly"]
    period_key: str
    current: int
    target: int
    reward_xp: int
    completed: bool
    awarded: bool


class BadgeProgressResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str
    title: str
    description: str
    category: Literal["starter", "consistency", "elite"]
    unlocked: bool
    unlocked_at: datetime | None


class GamificationSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    total_xp: int
    rank: str
    next_rank: str | None
    xp_to_next_rank: int
    daily_quests: list[QuestProgressResponse]
    weekly_quests: list[QuestProgressResponse]
    badges: list[BadgeProgressResponse]
    unlocked_badge_count: int
    total_badge_count: int
    leaderboard_position: int
    leaderboard_size: int


class LeaderboardEntryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position: int
    display_name: str = Field(min_length=1)
    total_xp: int
    rank: str
    is_current_user: bool


class LeaderboardResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[LeaderboardEntryResponse]
    limit: int
    offset: int
    returned: int
    total: int
