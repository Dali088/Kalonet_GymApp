from datetime import date, datetime, time
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_serializer, model_validator

MealType = Literal[
    "breakfast",
    "morning_snack",
    "lunch",
    "afternoon_snack",
    "dinner",
    "evening_snack",
]
MealSource = Literal["manual", "barcode"]
ActivityType = Literal["walking", "running", "cycling", "strength_training", "swimming", "other"]


class NutritionValues(BaseModel):
    model_config = ConfigDict(extra="forbid")

    calories_kcal: Decimal = Field(ge=0, le=100000)
    protein_g: Decimal = Field(ge=0, le=100000)
    carbohydrate_g: Decimal = Field(ge=0, le=100000)
    fat_g: Decimal = Field(ge=0, le=100000)

    @field_serializer("calories_kcal", "protein_g", "carbohydrate_g", "fat_g")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)


class NutritionTotals(NutritionValues):
    pass


class FoodSourceReference(BaseModel):
    model_config = ConfigDict(extra="forbid")

    provider: str = Field(min_length=1, max_length=64)
    barcode: str = Field(pattern=r"^\d{8,14}$")


class MealItemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=160)
    source: MealSource = "manual"
    source_reference: FoodSourceReference | None = None
    quantity: Decimal = Field(gt=0, le=100000)
    serving_description: str = Field(min_length=1, max_length=160)
    nutrition: NutritionValues

    @model_validator(mode="after")
    def validate_source_reference(self) -> "MealItemCreate":
        if self.source == "barcode" and self.source_reference is None:
            raise ValueError("Barcode items require a source reference.")
        if self.source == "manual" and self.source_reference is not None:
            raise ValueError("Manual items cannot include a source reference.")
        return self


class MealCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    record_date: date
    meal_type: MealType
    name: str = Field(min_length=1, max_length=100)
    recorded_time: time
    items: list[MealItemCreate] = Field(min_length=1, max_length=50)


class MealUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    meal_type: MealType | None = None
    record_date: date | None = None
    recorded_time: time | None = None
    name: str | None = Field(default=None, min_length=1, max_length=100)

    @model_validator(mode="after")
    def require_one_field(self) -> "MealUpdate":
        if all(
            value is None
            for value in (self.meal_type, self.record_date, self.recorded_time, self.name)
        ):
            raise ValueError("At least one meal field is required.")
        return self


class MealItemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=160)
    quantity: Decimal | None = Field(default=None, gt=0, le=100000)
    serving_description: str | None = Field(default=None, min_length=1, max_length=160)
    nutrition: NutritionValues | None = None

    @model_validator(mode="after")
    def require_one_field(self) -> "MealItemUpdate":
        if all(
            value is None
            for value in (self.name, self.quantity, self.serving_description, self.nutrition)
        ):
            raise ValueError("At least one item field is required.")
        return self


class MealItemResponse(BaseModel):
    id: UUID
    name: str
    source: MealSource
    quantity: Decimal
    serving_description: str
    nutrition: NutritionValues


class MealResponse(BaseModel):
    id: UUID
    meal_type: MealType
    name: str
    recorded_at: datetime
    totals: NutritionTotals
    items: list[MealItemResponse]


class MealsResponse(BaseModel):
    record_date: date
    items: list[MealResponse]
    daily_totals: NutritionTotals


class MealItemCreatedResponse(BaseModel):
    item: MealItemResponse
    meal: MealResponse


class WaterEntryCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    amount_ml: int = Field(ge=1, le=10000)
    recorded_at: datetime


class WaterEntryUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    amount_ml: int | None = Field(default=None, ge=1, le=10000)
    recorded_at: datetime | None = None

    @model_validator(mode="after")
    def require_one_field(self) -> "WaterEntryUpdate":
        if self.amount_ml is None and self.recorded_at is None:
            raise ValueError("At least one water field is required.")
        return self


class WaterEntryResponse(BaseModel):
    id: UUID
    amount_ml: int
    recorded_at: datetime
    record_date: date
    created_at: datetime | None = None


class WaterListResponse(BaseModel):
    record_date: date
    items: list[WaterEntryResponse]
    total_ml: int
    target_ml: int | None


class WaterCreatedResponse(WaterEntryResponse):
    daily_total_ml: int


class DailyStepsResponse(BaseModel):
    record_date: date
    step_count: int
    source: Literal["manual"] | None = None
    target: int | None = None
    updated_at: datetime | None


class DailyStepsUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_count: int = Field(ge=0, le=200000)
    source: Literal["manual"] = "manual"


class ActivityCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    activity_type: ActivityType
    name: str = Field(min_length=1, max_length=120)
    duration_minutes: int = Field(ge=1, le=1440)
    estimated_calories_kcal: Decimal | None = Field(default=None, ge=0, le=10000)
    recorded_at: datetime


class ActivityUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    activity_type: ActivityType | None = None
    name: str | None = Field(default=None, min_length=1, max_length=120)
    duration_minutes: int | None = Field(default=None, ge=1, le=1440)
    estimated_calories_kcal: Decimal | None = Field(default=None, ge=0, le=10000)
    recorded_at: datetime | None = None

    @model_validator(mode="after")
    def require_one_field(self) -> "ActivityUpdate":
        if all(
            value is None
            for value in (
                self.activity_type,
                self.name,
                self.duration_minutes,
                self.estimated_calories_kcal,
                self.recorded_at,
            )
        ):
            raise ValueError("At least one activity field is required.")
        return self


class ActivityResponse(BaseModel):
    id: UUID
    activity_type: ActivityType
    name: str
    duration_minutes: int
    estimated_calories_kcal: Decimal | None
    recorded_at: datetime


class ActivityTotals(BaseModel):
    duration_minutes: int
    estimated_calories_kcal: Decimal


class ActivityListResponse(BaseModel):
    record_date: date
    items: list[ActivityResponse]
    totals: ActivityTotals


class DashboardTarget(BaseModel):
    calories_kcal: int
    protein_g: int
    carbohydrate_g: int
    fat_g: int


class DashboardNutrition(BaseModel):
    target: DashboardTarget
    consumed: DashboardTarget
    remaining: DashboardTarget


class DashboardMeals(BaseModel):
    logged_meal_count: int
    logged_item_count: int


class DashboardWater(BaseModel):
    consumed_ml: int
    target_ml: int | None


class DashboardSteps(BaseModel):
    count: int
    target: int | None


class DashboardActivity(BaseModel):
    activity_count: int
    duration_minutes: int
    estimated_calories_kcal: Decimal


class DailyDashboardResponse(BaseModel):
    record_date: date
    time_zone: str
    nutrition: DashboardNutrition
    meals: DashboardMeals
    water: DashboardWater
    steps: DashboardSteps
    activity: DashboardActivity
    generated_at: datetime


class FoodNutrition(BaseModel):
    @field_serializer("calories_kcal", "protein_g", "carbohydrate_g", "fat_g")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)

    calories_kcal: Decimal
    protein_g: Decimal
    carbohydrate_g: Decimal
    fat_g: Decimal


class FoodProductResponse(BaseModel):
    barcode: str
    product: dict[str, str | FoodNutrition | None]
    provider: str
    retrieved_at: datetime
