from dataclasses import dataclass
from decimal import Decimal

import httpx
import pytest

from kalonet_backend.core.config import Settings
from kalonet_backend.services.meal_photo import (
    GeminiMealPhotoProvider,
    MealPhotoAnalysis,
    MealPhotoItem,
    MealPhotoNoFoodDetectedError,
    MealPhotoProvider,
    MealPhotoProviderInvalidResponseError,
    MealPhotoProviderRateLimitedError,
    MealPhotoProviderUnavailableError,
)


def _register(client, email: str) -> dict:
    response = client.post(
        "/api/v1/auth/registrations",
        json={"email": email, "password": "correct-horse-battery-staple"},
    )
    assert response.status_code == 201
    return response.json()


def _analysis() -> MealPhotoAnalysis:
    return MealPhotoAnalysis(
        items=[
            MealPhotoItem(
                name="Rice",
                estimated_grams=Decimal("180"),
                confidence=Decimal("0.86"),
                nutrition={
                    "calories_kcal": Decimal("234"),
                    "protein_g": Decimal("4.3"),
                    "carbohydrate_g": Decimal("51"),
                    "fat_g": Decimal("0.5"),
                },
            ),
            MealPhotoItem(
                name="Chicken",
                estimated_grams=Decimal("120"),
                confidence=Decimal("0.78"),
                nutrition={
                    "calories_kcal": Decimal("198"),
                    "protein_g": Decimal("37"),
                    "carbohydrate_g": Decimal("0"),
                    "fat_g": Decimal("4.3"),
                },
            ),
        ],
        overall_confidence=Decimal("0.82"),
    )


@dataclass
class _FakeMealPhotoProvider(MealPhotoProvider):
    result: MealPhotoAnalysis | None = None
    error: Exception | None = None
    called: bool = False

    def analyze(self, image_bytes: bytes, mime_type: str) -> MealPhotoAnalysis:
        self.called = True
        if self.error is not None:
            raise self.error
        assert image_bytes.startswith(b"\xff\xd8\xff")
        assert mime_type == "image/jpeg"
        assert self.result is not None
        return self.result


def _with_provider(client, provider: _FakeMealPhotoProvider):
    previous = client.app.state.meal_photo_provider
    client.app.state.meal_photo_provider = provider
    return previous


def test_meal_photo_analysis_returns_multiple_editable_items(client) -> None:
    session = _register(client, "meal-photo-success@example.com")
    provider = _FakeMealPhotoProvider(result=_analysis())
    previous = _with_provider(client, provider)

    try:
        response = client.post(
            "/api/v1/ai/meal-photo-analyses",
            headers={"Authorization": f"Bearer {session['access_token']}"},
            files={"image": ("meal.jpg", b"\xff\xd8\xffmeal", "image/jpeg")},
        )
    finally:
        client.app.state.meal_photo_provider = previous

    assert response.status_code == 200
    assert provider.called
    assert [item["name"] for item in response.json()["items"]] == ["Rice", "Chicken"]
    assert response.json()["items"][0]["nutrition"]["calories_kcal"] == 234.0


def test_meal_photo_rejects_invalid_upload_before_provider(client) -> None:
    session = _register(client, "meal-photo-invalid@example.com")
    provider = _FakeMealPhotoProvider(result=_analysis())
    previous = _with_provider(client, provider)

    try:
        response = client.post(
            "/api/v1/ai/meal-photo-analyses",
            headers={"Authorization": f"Bearer {session['access_token']}"},
            files={"image": ("meal.txt", b"not-an-image", "text/plain")},
        )
    finally:
        client.app.state.meal_photo_provider = previous

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_image"
    assert not provider.called


def test_meal_photo_rejects_oversized_upload(client) -> None:
    session = _register(client, "meal-photo-large@example.com")
    provider = _FakeMealPhotoProvider(result=_analysis())
    previous = _with_provider(client, provider)

    try:
        response = client.post(
            "/api/v1/ai/meal-photo-analyses",
            headers={"Authorization": f"Bearer {session['access_token']}"},
            files={
                "image": (
                    "meal.jpg",
                    b"\xff\xd8\xff" + b"x" * (5 * 1024 * 1024),
                    "image/jpeg",
                )
            },
        )
    finally:
        client.app.state.meal_photo_provider = previous

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "image_too_large"
    assert not provider.called


@pytest.mark.parametrize(
    ("provider_error", "status_code", "error_code"),
    [
        (MealPhotoNoFoodDetectedError(), 422, "ai_no_food_detected"),
        (MealPhotoProviderRateLimitedError(), 429, "ai_provider_rate_limited"),
        (MealPhotoProviderInvalidResponseError(), 502, "ai_provider_invalid_response"),
        (MealPhotoProviderUnavailableError(), 503, "ai_provider_unavailable"),
    ],
)
def test_meal_photo_maps_provider_failures(
    client,
    provider_error: Exception,
    status_code: int,
    error_code: str,
) -> None:
    session = _register(client, f"meal-photo-{status_code}@example.com")
    provider = _FakeMealPhotoProvider(error=provider_error)
    previous = _with_provider(client, provider)

    try:
        response = client.post(
            "/api/v1/ai/meal-photo-analyses",
            headers={"Authorization": f"Bearer {session['access_token']}"},
            files={"image": ("meal.jpg", b"\xff\xd8\xffmeal", "image/jpeg")},
        )
    finally:
        client.app.state.meal_photo_provider = previous

    assert response.status_code == status_code
    assert response.json()["error"]["code"] == error_code


def test_meal_photo_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/ai/meal-photo-analyses",
        files={"image": ("meal.jpg", b"\xff\xd8\xffmeal", "image/jpeg")},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_access_token"


def test_gemini_provider_parses_structured_json_without_live_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/models/gemini-2.5-flash:generateContent")
        assert request.url.params["key"] == "test-key"
        payload = request.content
        assert b"inline_data" in payload
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": (
                                        '{"items":[{"name":"Soup",'
                                        '"estimated_grams":250,"confidence":0.9,'
                                        '"nutrition":{"calories_kcal":180,"protein_g":8,'
                                        '"carbohydrate_g":20,"fat_g":6}}],'
                                        '"overall_confidence":0.9,'
                                        '"disclaimer":"Review before saving."}'
                                    )
                                }
                            ]
                        }
                    }
                ]
            },
            request=request,
        )

    provider = GeminiMealPhotoProvider(
        Settings(
            gemini_api_key="test-key",
            gemini_model="gemini-2.5-flash",
            gemini_max_attempts=1,
        ),
        transport=httpx.MockTransport(handler),
    )

    result = provider.analyze(b"\xff\xd8\xffmeal", "image/jpeg")

    assert result.items[0].name == "Soup"
    assert result.items[0].nutrition["calories_kcal"] == Decimal("180")
