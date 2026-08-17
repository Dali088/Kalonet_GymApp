from dataclasses import replace
from datetime import date
from decimal import Decimal

import pytest

from kalonet_backend.services.nutrition import (
    NutritionCalculationInputs,
    NutritionCalculationService,
    UnsupportedNutritionProfileError,
)


def valid_inputs() -> NutritionCalculationInputs:
    return NutritionCalculationInputs(
        goal="weight_loss",
        date_of_birth=date(2004, 3, 14),
        sex_for_formula="male",
        height_cm=Decimal("180"),
        weight_kg=Decimal("82.5"),
        activity_level="moderately_active",
    )


def test_nutrition_calculation_is_deterministic() -> None:
    service = NutritionCalculationService()

    first = service.calculate(valid_inputs(), as_of=date(2026, 8, 1))
    second = service.calculate(valid_inputs(), as_of=date(2026, 8, 1))

    assert first == second
    assert first.rule_version == "nutrition_rules_v1"
    assert first.daily_calories > 0
    assert first.protein_g > 0
    assert first.carbohydrate_g > 0
    assert first.fat_g > 0


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("date_of_birth", date(2010, 1, 1)),
        ("height_cm", Decimal("119")),
        ("weight_kg", Decimal("34")),
    ],
)
def test_nutrition_calculation_rejects_unsupported_profiles(
    field: str,
    value: object,
) -> None:
    values = replace(valid_inputs(), **{field: value})

    with pytest.raises(UnsupportedNutritionProfileError):
        NutritionCalculationService().calculate(
            values,
            as_of=date(2026, 8, 1),
        )
