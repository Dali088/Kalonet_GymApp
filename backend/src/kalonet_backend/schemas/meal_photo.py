from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class MealPhotoNutrition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    calories_kcal: Decimal = Field(ge=0, le=100000)
    protein_g: Decimal = Field(ge=0, le=100000)
    carbohydrate_g: Decimal = Field(ge=0, le=100000)
    fat_g: Decimal = Field(ge=0, le=100000)

    @field_serializer("calories_kcal", "protein_g", "carbohydrate_g", "fat_g")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)


class MealPhotoItemResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=160)
    estimated_grams: Decimal = Field(gt=0, le=2000)
    confidence: Decimal = Field(ge=0, le=1)
    nutrition: MealPhotoNutrition

    @field_serializer("estimated_grams", "confidence")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)


class MealPhotoAnalysisResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[MealPhotoItemResponse] = Field(min_length=1, max_length=10)
    overall_confidence: Decimal = Field(ge=0, le=1)
    disclaimer: str = Field(min_length=1, max_length=300)

    @field_serializer("overall_confidence")
    def serialize_decimal(self, value: Decimal) -> float:
        return float(value)
