import httpx

from kalonet_backend.core.config import Settings
from kalonet_backend.services.food_provider import (
    FoodProviderInvalidResponseError,
    OpenFoodFactsProvider,
)


def test_open_food_facts_normalizes_a_valid_product() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/product/12345678.json")
        return httpx.Response(
            200,
            json={
                "status": 1,
                "code": "12345678",
                "product": {
                    "product_name": "Example cereal",
                    "brands": "Example",
                    "serving_size": "30 g",
                    "nutriments": {
                        "energy-kcal_100g": 380,
                        "proteins_100g": 8,
                        "carbohydrates_100g": 70,
                        "fat_100g": 5,
                    },
                },
            },
            request=request,
        )

    provider = OpenFoodFactsProvider(
        Settings(food_provider_max_attempts=1), transport=httpx.MockTransport(handler)
    )
    product = provider.lookup("12345678")

    assert product is not None
    assert product.name == "Example cereal"
    assert product.nutrition["calories_kcal"] == 380


def test_open_food_facts_rejects_missing_nutrition() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"status": 1, "product": {"product_name": "Incomplete", "nutriments": {}}},
            request=request,
        )

    provider = OpenFoodFactsProvider(
        Settings(food_provider_max_attempts=1), transport=httpx.MockTransport(handler)
    )

    try:
        provider.lookup("12345678")
    except FoodProviderInvalidResponseError:
        pass
    else:
        raise AssertionError("invalid provider data should be rejected")
