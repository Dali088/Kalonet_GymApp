from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal


class UnsupportedNutritionProfileError(ValueError):
    """Raised when inputs fall outside Kalonet's approved wellness policy."""


@dataclass(frozen=True, slots=True)
class NutritionCalculationInputs:
    goal: str
    date_of_birth: date
    sex_for_formula: str
    height_cm: Decimal
    weight_kg: Decimal
    activity_level: str


@dataclass(frozen=True, slots=True)
class NutritionCalculationResult:
    age_years: int
    activity_multiplier: Decimal
    bmr_kcal: Decimal
    tdee_kcal: Decimal
    goal_adjustment_kcal: int
    daily_calories: int
    protein_g: int
    carbohydrate_g: int
    fat_g: int
    rule_version: str
    warnings: tuple[str, ...]


class NutritionCalculationService:
    """Pure, deterministic implementation of the Kalonet nutrition rules."""

    RULE_VERSION = "nutrition_rules_v1"
    ACTIVITY_MULTIPLIERS = {
        "sedentary": Decimal("1.200"),
        "lightly_active": Decimal("1.375"),
        "moderately_active": Decimal("1.550"),
        "very_active": Decimal("1.725"),
    }
    GOAL_ADJUSTMENTS = {
        "weight_loss": -400,
        "maintain_weight": 0,
        "weight_gain": 300,
    }

    def calculate(
        self,
        inputs: NutritionCalculationInputs,
        *,
        as_of: date,
    ) -> NutritionCalculationResult:
        age_years = self._age_on(inputs.date_of_birth, as_of)
        self._validate(inputs, age_years)

        multiplier = self.ACTIVITY_MULTIPLIERS[inputs.activity_level]
        weight = inputs.weight_kg
        height = inputs.height_cm
        age = Decimal(age_years)

        # Mifflin-St Jeor estimates resting energy expenditure.
        sex_constant = Decimal("5") if inputs.sex_for_formula == "male" else Decimal("-161")
        bmr = Decimal("10") * weight + Decimal("6.25") * height - Decimal("5") * age + sex_constant
        tdee = bmr * multiplier
        adjustment = self.GOAL_ADJUSTMENTS[inputs.goal]
        proposed_calories = self._round_integer(tdee) + adjustment

        floor = 1500 if inputs.sex_for_formula == "male" else 1200
        warnings: list[str] = []
        daily_calories = max(proposed_calories, floor)
        if daily_calories != proposed_calories:
            warnings.append("A safety calorie floor was applied to this target.")

        protein_g = self._round_integer(weight * Decimal("2"))
        fat_g = self._round_integer(Decimal(daily_calories) * Decimal("0.25") / Decimal("9"))
        carbohydrate_g = self._round_integer(
            (Decimal(daily_calories) - Decimal(protein_g * 4) - Decimal(fat_g * 9)) / Decimal("4")
        )

        if carbohydrate_g < 0:
            raise UnsupportedNutritionProfileError

        return NutritionCalculationResult(
            age_years=age_years,
            activity_multiplier=multiplier,
            bmr_kcal=bmr.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP),
            tdee_kcal=tdee.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP),
            goal_adjustment_kcal=adjustment,
            daily_calories=daily_calories,
            protein_g=protein_g,
            carbohydrate_g=carbohydrate_g,
            fat_g=fat_g,
            rule_version=self.RULE_VERSION,
            warnings=tuple(warnings),
        )

    @staticmethod
    def _round_integer(value: Decimal) -> int:
        return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))

    @staticmethod
    def _age_on(birth_date: date, as_of: date) -> int:
        age = as_of.year - birth_date.year
        if (as_of.month, as_of.day) < (birth_date.month, birth_date.day):
            age -= 1
        return age

    def _validate(self, inputs: NutritionCalculationInputs, age_years: int) -> None:
        if not 18 <= age_years <= 65:
            raise UnsupportedNutritionProfileError
        if not 120 <= inputs.height_cm <= 230:
            raise UnsupportedNutritionProfileError
        if not 35 <= inputs.weight_kg <= 300:
            raise UnsupportedNutritionProfileError
        if inputs.sex_for_formula not in {"male", "female"}:
            raise UnsupportedNutritionProfileError
        if inputs.goal not in self.GOAL_ADJUSTMENTS:
            raise UnsupportedNutritionProfileError
        if inputs.activity_level not in self.ACTIVITY_MULTIPLIERS:
            raise UnsupportedNutritionProfileError
