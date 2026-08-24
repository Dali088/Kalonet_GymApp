import base64
import json
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Protocol

import httpx

from kalonet_backend.core.config import Settings

MAX_MEAL_PHOTO_BYTES = 5 * 1024 * 1024
ALLOWED_MEAL_PHOTO_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})
DEFAULT_MEAL_PHOTO_DISCLAIMER = (
    "AI nutrition values are estimates. Review and edit them before saving."
)


class MealPhotoInvalidImageError(Exception):
    """The upload is not a supported image."""


class MealPhotoTooLargeError(Exception):
    """The upload is larger than the bounded analysis limit."""


class MealPhotoNoFoodDetectedError(Exception):
    """The provider found no usable food item."""


class MealPhotoLowConfidenceError(Exception):
    """The provider's proposal is too uncertain to present."""


class MealPhotoProviderUnavailableError(Exception):
    """The provider could not be reached or is not configured."""


class MealPhotoProviderInvalidResponseError(Exception):
    """The provider response could not be trusted as structured data."""


class MealPhotoProviderRateLimitedError(Exception):
    """The provider rejected the request because of quota or rate limits."""


@dataclass(frozen=True)
class MealPhotoItem:
    name: str
    estimated_grams: Decimal
    confidence: Decimal
    nutrition: dict[str, Decimal]


@dataclass(frozen=True)
class MealPhotoAnalysis:
    items: list[MealPhotoItem]
    overall_confidence: Decimal
    disclaimer: str = DEFAULT_MEAL_PHOTO_DISCLAIMER


class MealPhotoProvider(Protocol):
    def analyze(self, image_bytes: bytes, mime_type: str) -> MealPhotoAnalysis:
        """Return a validated, editable proposal for an image."""


class MealPhotoService:
    """Validate an upload and delegate analysis to an injectable provider."""

    def __init__(self, provider: MealPhotoProvider) -> None:
        self.provider = provider

    def analyze(self, image_bytes: bytes, mime_type: str) -> MealPhotoAnalysis:
        validate_meal_photo(image_bytes, mime_type)
        return _validate_analysis(self.provider.analyze(image_bytes, mime_type))


def validate_meal_photo(image_bytes: bytes, mime_type: str) -> None:
    if mime_type not in ALLOWED_MEAL_PHOTO_TYPES:
        raise MealPhotoInvalidImageError
    if len(image_bytes) > MAX_MEAL_PHOTO_BYTES:
        raise MealPhotoTooLargeError
    if not _has_supported_signature(image_bytes, mime_type):
        raise MealPhotoInvalidImageError


def _validate_analysis(analysis: MealPhotoAnalysis) -> MealPhotoAnalysis:
    """Apply the same trust boundary to fake and production providers."""

    if not isinstance(analysis, MealPhotoAnalysis) or not 1 <= len(analysis.items) <= 10:
        raise MealPhotoProviderInvalidResponseError
    try:
        items = [
            MealPhotoItem(
                name=item.name.strip(),
                estimated_grams=_decimal(item.estimated_grams, 0, 2000),
                confidence=_decimal(item.confidence, 0, 1),
                nutrition={
                    key: _decimal(item.nutrition[key], 0, 100000)
                    for key in (
                        "calories_kcal",
                        "protein_g",
                        "carbohydrate_g",
                        "fat_g",
                    )
                },
            )
            for item in analysis.items
        ]
        if any(not item.name for item in items):
            raise ValueError
        overall_confidence = _decimal(analysis.overall_confidence, 0, 1)
    except (AttributeError, KeyError, TypeError, ValueError, InvalidOperation) as exc:
        raise MealPhotoProviderInvalidResponseError from exc
    if overall_confidence < Decimal("0.35"):
        raise MealPhotoLowConfidenceError
    disclaimer = analysis.disclaimer
    if not isinstance(disclaimer, str) or not 1 <= len(disclaimer) <= 300:
        disclaimer = DEFAULT_MEAL_PHOTO_DISCLAIMER
    return MealPhotoAnalysis(items, overall_confidence, disclaimer)


def _has_supported_signature(image_bytes: bytes, mime_type: str) -> bool:
    if mime_type == "image/jpeg":
        return image_bytes.startswith(b"\xff\xd8\xff")
    if mime_type == "image/png":
        return image_bytes.startswith(b"\x89PNG\r\n\x1a\n")
    return len(image_bytes) >= 12 and image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP"


class GeminiMealPhotoProvider:
    """Call Gemini's vision endpoint and normalize its untrusted JSON output."""

    def __init__(self, settings: Settings, *, transport: httpx.BaseTransport | None = None) -> None:
        self.api_key = (
            settings.gemini_api_key.get_secret_value() if settings.gemini_api_key else None
        )
        self.model = settings.gemini_model
        self.base_url = settings.gemini_base_url.rstrip("/")
        self.timeout = settings.gemini_timeout_seconds
        self.max_attempts = settings.gemini_max_attempts
        self.transport = transport

    def analyze(self, image_bytes: bytes, mime_type: str) -> MealPhotoAnalysis:
        if not self.api_key:
            raise MealPhotoProviderUnavailableError

        prompt = (
            "Analyze this meal photo. Return only JSON matching the provided schema. "
            "Identify visible foods, estimate each portion in grams, and estimate calories "
            "and macros for that portion. Do not invent certainty. If no food is visible, "
            "return an empty items array and overall_confidence 0."
        )
        body = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": base64.b64encode(image_bytes).decode("ascii"),
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": _response_schema(),
                "temperature": 0.1,
            },
        }
        url = f"{self.base_url}/models/{self.model}:generateContent"
        for attempt in range(self.max_attempts):
            try:
                with httpx.Client(timeout=self.timeout, transport=self.transport) as client:
                    response = client.post(
                        url,
                        params={"key": self.api_key},
                        headers={"Accept": "application/json"},
                        json=body,
                    )
            except (httpx.TimeoutException, httpx.ConnectError) as exc:
                if attempt + 1 == self.max_attempts:
                    raise MealPhotoProviderUnavailableError from exc
                continue

            if response.status_code == 429:
                raise MealPhotoProviderRateLimitedError
            if response.status_code >= 500:
                if attempt + 1 < self.max_attempts:
                    continue
                raise MealPhotoProviderUnavailableError
            if response.status_code != 200:
                raise MealPhotoProviderInvalidResponseError
            return _parse_gemini_response(response)
        raise MealPhotoProviderUnavailableError


def _parse_gemini_response(response: httpx.Response) -> MealPhotoAnalysis:
    try:
        payload = response.json()
        text = payload["candidates"][0]["content"]["parts"][0]["text"]
        output = json.loads(text)
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise MealPhotoProviderInvalidResponseError from exc

    if not isinstance(output, dict):
        raise MealPhotoProviderInvalidResponseError
    raw_items = output.get("items")
    if raw_items == []:
        raise MealPhotoNoFoodDetectedError
    if not isinstance(raw_items, list) or not 1 <= len(raw_items) <= 10:
        raise MealPhotoProviderInvalidResponseError

    items: list[MealPhotoItem] = []
    try:
        for raw_item in raw_items:
            if not isinstance(raw_item, dict):
                raise ValueError
            name = raw_item["name"]
            if not isinstance(name, str) or not 1 <= len(name.strip()) <= 160:
                raise ValueError
            nutrition = raw_item["nutrition"]
            if not isinstance(nutrition, dict):
                raise ValueError
            item = MealPhotoItem(
                name=name.strip(),
                estimated_grams=_decimal(raw_item["estimated_grams"], 0, 2000),
                confidence=_decimal(raw_item["confidence"], 0, 1),
                nutrition={
                    key: _decimal(nutrition[key], 0, 100000)
                    for key in (
                        "calories_kcal",
                        "protein_g",
                        "carbohydrate_g",
                        "fat_g",
                    )
                },
            )
            items.append(item)
        overall_confidence = _decimal(output["overall_confidence"], 0, 1)
    except (KeyError, TypeError, ValueError, InvalidOperation) as exc:
        raise MealPhotoProviderInvalidResponseError from exc

    if overall_confidence < Decimal("0.35"):
        raise MealPhotoLowConfidenceError
    disclaimer = output.get("disclaimer", DEFAULT_MEAL_PHOTO_DISCLAIMER)
    if not isinstance(disclaimer, str) or not 1 <= len(disclaimer) <= 300:
        disclaimer = DEFAULT_MEAL_PHOTO_DISCLAIMER
    return MealPhotoAnalysis(items, overall_confidence, disclaimer)


def _decimal(value: object, minimum: int, maximum: int) -> Decimal:
    if isinstance(value, bool):
        raise ValueError
    decimal = Decimal(str(value))
    if not minimum <= decimal <= maximum:
        raise ValueError
    return decimal


def _response_schema() -> dict[str, object]:
    nutrition = {
        "type": "OBJECT",
        "properties": {
            "calories_kcal": {"type": "NUMBER"},
            "protein_g": {"type": "NUMBER"},
            "carbohydrate_g": {"type": "NUMBER"},
            "fat_g": {"type": "NUMBER"},
        },
        "required": ["calories_kcal", "protein_g", "carbohydrate_g", "fat_g"],
    }
    item = {
        "type": "OBJECT",
        "properties": {
            "name": {"type": "STRING"},
            "estimated_grams": {"type": "NUMBER"},
            "confidence": {"type": "NUMBER"},
            "nutrition": nutrition,
        },
        "required": ["name", "estimated_grams", "confidence", "nutrition"],
    }
    return {
        "type": "OBJECT",
        "properties": {
            "items": {"type": "ARRAY", "items": item},
            "overall_confidence": {"type": "NUMBER"},
            "disclaimer": {"type": "STRING"},
        },
        "required": ["items", "overall_confidence", "disclaimer"],
    }


__all__ = [
    "ALLOWED_MEAL_PHOTO_TYPES",
    "DEFAULT_MEAL_PHOTO_DISCLAIMER",
    "GeminiMealPhotoProvider",
    "MAX_MEAL_PHOTO_BYTES",
    "MealPhotoAnalysis",
    "MealPhotoInvalidImageError",
    "MealPhotoItem",
    "MealPhotoLowConfidenceError",
    "MealPhotoNoFoodDetectedError",
    "MealPhotoProvider",
    "MealPhotoProviderInvalidResponseError",
    "MealPhotoProviderRateLimitedError",
    "MealPhotoProviderUnavailableError",
    "MealPhotoService",
    "MealPhotoTooLargeError",
]
