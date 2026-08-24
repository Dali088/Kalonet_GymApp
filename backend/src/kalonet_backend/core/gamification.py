from dataclasses import dataclass

DEFAULT_STEP_TARGET = 10_000
DEFAULT_WATER_TARGET_ML = 2_500


@dataclass(frozen=True)
class RankDefinition:
    code: str
    minimum_xp: int


RANKS: tuple[RankDefinition, ...] = (
    RankDefinition("E", 0),
    RankDefinition("D", 500),
    RankDefinition("C", 1_500),
    RankDefinition("B", 3_500),
    RankDefinition("A", 7_000),
    RankDefinition("S", 12_000),
)


@dataclass(frozen=True)
class QuestDefinition:
    code: str
    title: str
    description: str
    period: str
    target: int
    reward_xp: int


DAILY_QUESTS: tuple[QuestDefinition, ...] = (
    QuestDefinition("daily_meal", "Daily meal", "Log at least one meal", "daily", 1, 10),
    QuestDefinition(
        "daily_hydration",
        "Hydration target",
        "Drink 2,500 ml of water",
        "daily",
        DEFAULT_WATER_TARGET_ML,
        15,
    ),
    QuestDefinition(
        "daily_steps",
        "Step target",
        "Reach 10,000 steps",
        "daily",
        DEFAULT_STEP_TARGET,
        15,
    ),
    QuestDefinition("daily_activity", "Daily activity", "Log one activity", "daily", 1, 10),
)

WEEKLY_QUESTS: tuple[QuestDefinition, ...] = (
    QuestDefinition(
        "weekly_meals_5_days",
        "Meal consistency",
        "Log meals on five distinct days",
        "weekly",
        5,
        100,
    ),
    QuestDefinition(
        "weekly_hydration_5_days",
        "Hydration consistency",
        "Reach the hydration target on five distinct days",
        "weekly",
        5,
        120,
    ),
    QuestDefinition(
        "weekly_steps_4_days",
        "Step consistency",
        "Reach the step target on four distinct days",
        "weekly",
        4,
        120,
    ),
)


@dataclass(frozen=True)
class BadgeDefinition:
    code: str
    title: str
    description: str
    category: str


BADGES: tuple[BadgeDefinition, ...] = (
    BadgeDefinition("FIRST_MEAL", "First meal", "Log your first meal", "starter"),
    BadgeDefinition(
        "FIRST_HYDRATION_GOAL",
        "First hydration goal",
        "Reach your first hydration target",
        "starter",
    ),
    BadgeDefinition(
        "FIRST_STEP_GOAL", "First step goal", "Reach your first step target", "starter"
    ),
    BadgeDefinition("FIRST_ACTIVITY", "First activity", "Log your first activity", "starter"),
    BadgeDefinition(
        "MEAL_7_DAYS", "Meal consistency", "Log meals on seven distinct days", "consistency"
    ),
    BadgeDefinition(
        "HYDRATION_7_DAYS",
        "Hydration consistency",
        "Reach hydration target on seven distinct days",
        "consistency",
    ),
    BadgeDefinition(
        "STEPS_7_DAYS",
        "Step consistency",
        "Reach step target on seven distinct days",
        "consistency",
    ),
    BadgeDefinition(
        "ACTIVITY_5_DAYS",
        "Activity consistency",
        "Log activity on five distinct days",
        "consistency",
    ),
    BadgeDefinition("RANK_D", "Rank D", "Reach rank D", "elite"),
    BadgeDefinition("RANK_C", "Rank C", "Reach rank C", "elite"),
    BadgeDefinition("RANK_B", "Rank B", "Reach rank B", "elite"),
    BadgeDefinition("RANK_A", "Rank A", "Reach rank A", "elite"),
    BadgeDefinition("RANK_S", "Rank S", "Reach rank S", "elite"),
)


def rank_for_xp(total_xp: int) -> RankDefinition:
    """Derive a rank from server-stored XP; rank is never client supplied."""

    current = RANKS[0]
    for rank in RANKS:
        if total_xp >= rank.minimum_xp:
            current = rank
        else:
            break
    return current


def next_rank_for_xp(total_xp: int) -> RankDefinition | None:
    current = rank_for_xp(total_xp)
    for rank in RANKS:
        if rank.minimum_xp > current.minimum_xp:
            return rank
    return None
