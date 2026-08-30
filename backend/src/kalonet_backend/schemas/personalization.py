from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_serializer,
    field_validator,
    model_validator,
)

Goal = Literal["weight_loss", "maintain_weight", "weight_gain"]
SexForFormula = Literal["male", "female"]
ActivityLevel = Literal[
    "sedentary",
    "lightly_active",
    "moderately_active",
    "very_active",
]
OnboardingStatus = Literal["not_started", "in_progress", "completed"]
NutritionTargetStatus = Literal["not_calculated", "active"]


class Measurements(BaseModel):
    """Complete metric inputs used by the nutrition calculation."""

    model_config = ConfigDict(extra="forbid")

    date_of_birth: date
    sex_for_formula: SexForFormula
    height_cm: Decimal = Field(ge=Decimal("120"), le=Decimal("230"))
    weight_kg: Decimal = Field(ge=Decimal("35"), le=Decimal("300"))

    @field_serializer("height_cm", "weight_kg")
    def serialize_decimal(self, value: Decimal) -> float:
        """Expose measurement decimals as JSON numbers in the API contract."""

        return float(value)


class MealScheduleInput(BaseModel):
    """One local preferred meal time and its positional display order."""

    model_config = ConfigDict(extra="forbid")

    preferred_time: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    display_order: int = Field(ge=1, le=15)


class OnboardingDraftPatch(BaseModel):
    """Absolute updates for any supplied onboarding section."""

    model_config = ConfigDict(extra="forbid")

    goal: Goal | None = None
    measurements: Measurements | None = None
    activity_level: ActivityLevel | None = None
    dietary_preferences: list[str] | None = None
    meal_schedule: list[MealScheduleInput] | None = None

    @model_validator(mode="after")
    def require_one_field(self) -> "OnboardingDraftPatch":
        if all(
            value is None
            for value in (
                self.goal,
                self.measurements,
                self.activity_level,
                self.dietary_preferences,
                self.meal_schedule,
            )
        ):
            raise ValueError("At least one onboarding field is required.")
        if self.meal_schedule is not None and not 1 <= len(self.meal_schedule) <= 15:
            raise ValueError("Meal schedule must contain between 1 and 15 meals.")
        return self


class OnboardingCompletionRequest(BaseModel):
    """Explicit acknowledgement required before activating a target."""

    model_config = ConfigDict(extra="forbid")

    accepted_target: bool


class OnboardingStateResponse(BaseModel):
    """Resumable onboarding state returned to the client."""

    status: OnboardingStatus
    goal: Goal | None
    measurements: Measurements | None
    activity_level: ActivityLevel | None
    dietary_preferences: list[str]
    meal_schedule: list[MealScheduleInput]
    missing_fields: list[str]
    nutrition_target_status: NutritionTargetStatus
    updated_at: datetime


class PreviewInputs(BaseModel):
    goal: Goal
    age_years: int
    sex_for_formula: SexForFormula
    height_cm: Decimal
    weight_kg: Decimal
    activity_level: ActivityLevel

    @field_serializer("height_cm", "weight_kg")
    def serialize_decimal(self, value: Decimal) -> float:
        """Expose preview measurement decimals as JSON numbers."""

        return float(value)


class CalculationSummary(BaseModel):
    bmr_kcal: int
    tdee_kcal: int
    goal_adjustment_kcal: int


class OnboardingTargetResponse(BaseModel):
    id: str
    calculation_version: str
    calories_kcal: int
    protein_g: int
    carbohydrate_g: int
    fat_g: int
    effective_from: date
    is_active: bool


class NutritionPreviewResponse(BaseModel):
    calculation_version: str
    inputs: PreviewInputs
    calculation: CalculationSummary
    target: OnboardingTargetResponse
    warnings: list[str]
    calculated_at: datetime


class OnboardingCompletionResponse(BaseModel):
    onboarding_completed: bool
    completed_at: datetime
    nutrition_target: OnboardingTargetResponse


class CurrentNutritionTargetResponse(BaseModel):
    id: str
    calculation_version: str
    calories_kcal: int
    protein_g: int
    carbohydrate_g: int
    fat_g: int
    effective_from: date
    is_active: bool
    created_at: datetime


class ProfileUserResponse(BaseModel):
    id: str
    email: str
    nickname: str | None
    avatar_present: bool
    onboarding_completed: bool
    onboarding_completed_at: datetime


class ProfileTargetResponse(BaseModel):
    id: str
    daily_calories: int
    protein_g: int
    carbohydrate_g: int
    fat_g: int
    effective_from: date
    rule_version: str
    is_active: bool


class ProfileCalculationInputs(BaseModel):
    goal: Goal
    date_of_birth: date
    formula_sex: SexForFormula
    height_cm: Decimal
    weight_kg: Decimal
    activity_level: ActivityLevel

    @field_serializer("height_cm", "weight_kg")
    def serialize_decimal(self, value: Decimal) -> float:
        """Expose profile measurement decimals as JSON numbers."""

        return float(value)


class ProfileResponse(BaseModel):
    user: ProfileUserResponse
    calculation_inputs: ProfileCalculationInputs
    current_nutrition_target: ProfileTargetResponse
    dietary_preferences: list[str]
    meal_schedule: list[MealScheduleInput]


class ProfileNicknameUpdate(BaseModel):
    """Set a trimmed optional nickname; JSON null clears it."""

    model_config = ConfigDict(extra="forbid")

    nickname: str | None

    @field_validator("nickname")
    @classmethod
    def normalize_nickname(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("Nickname must not be blank.")
        return normalized


class NutritionRecalculationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    goal: Goal
    date_of_birth: date
    formula_sex: SexForFormula
    height_cm: Decimal = Field(ge=Decimal("120"), le=Decimal("230"))
    weight_kg: Decimal = Field(ge=Decimal("35"), le=Decimal("300"))
    activity_level: ActivityLevel


class RecalculationInputs(BaseModel):
    goal: Goal
    height_cm: Decimal
    weight_kg: Decimal
    activity_level: ActivityLevel


class RecalculationResponse(BaseModel):
    calculation_inputs: RecalculationInputs
    nutrition_target: ProfileTargetResponse
    previous_target_id: str


class PreferencesReplaceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    preferences: list[str]


class PreferencesResponse(BaseModel):
    preferences: list[str]
    updated_at: datetime


class MealScheduleReplaceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[MealScheduleInput] = Field(min_length=1, max_length=15)


class MealScheduleResponse(BaseModel):
    items: list[MealScheduleInput]
    updated_at: datetime


MeasurementSystem = Literal["metric", "imperial"]
ThemePreference = Literal["system", "light", "dark"]


class SettingsResponse(BaseModel):
    measurement_system: MeasurementSystem
    time_zone: str
    theme_preference: ThemePreference


class SettingsPatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    measurement_system: MeasurementSystem | None = None
    time_zone: str | None = None
    theme_preference: ThemePreference | None = None

    @model_validator(mode="after")
    def require_one_setting(self) -> "SettingsPatchRequest":
        if (
            self.measurement_system is None
            and self.time_zone is None
            and self.theme_preference is None
        ):
            raise ValueError("At least one setting is required.")
        return self


class PasswordChangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: str = Field(min_length=1, max_length=128)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        from kalonet_backend.core.security.password_policy import validate_new_password

        return validate_new_password(value)


class AccountDeletionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: str = Field(min_length=1, max_length=128)
    confirmation: str | None = None
