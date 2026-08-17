from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import Protocol

import httpx

from kalonet_backend.core.config import Settings


class FoodProviderUnavailableError(Exception):
    """The provider could not be reached after bounded retries."""


class FoodProviderInvalidResponseError(Exception):
    """The provider responded, but its payload was unusable."""


class FoodProviderRateLimitedError(Exception):
    """The provider explicitly rejected the request due to quota."""


@dataclass(frozen=True)
class FoodProduct:
    barcode: str
    name: str
    brand: str | None
    serving_description: str
    nutrition: dict[str, Decimal]
    provider: str
    retrieved_at: datetime


class FoodProvider(Protocol):
    def lookup(self, barcode: str) -> FoodProduct | None:
        """Return a normalized product proposal or None when no product exists."""


class OpenFoodFactsProvider:
    """Translate Open Food Facts HTTP responses into Kalonet's small provider shape."""

    def __init__(self, settings: Settings, *, transport: httpx.BaseTransport | None = None) -> None:
        self.base_url = settings.food_provider_base_url.rstrip("/")
        self.user_agent = settings.food_provider_user_agent
        self.timeout = settings.food_provider_timeout_seconds
        self.max_attempts = settings.food_provider_max_attempts
        self.transport = transport

    def lookup(self, barcode: str) -> FoodProduct | None:
        headers = {"User-Agent": self.user_agent, "Accept": "application/json"}
        for attempt in range(self.max_attempts):
            try:
                with httpx.Client(
                    timeout=self.timeout, headers=headers, transport=self.transport
                ) as client:
                    response = client.get(f"{self.base_url}/product/{barcode}.json")
            except (httpx.TimeoutException, httpx.ConnectError) as exc:
                if attempt + 1 == self.max_attempts:
                    raise FoodProviderUnavailableError from exc
                continue
            if response.status_code == 429:
                raise FoodProviderRateLimitedError
            if response.status_code == 404:
                return None
            if response.status_code >= 500:
                if attempt + 1 < self.max_attempts:
                    continue
                raise FoodProviderUnavailableError
            if response.status_code != 200:
                raise FoodProviderInvalidResponseError
            return self._parse(response)
        raise FoodProviderUnavailableError

    @staticmethod
    def _parse(response: httpx.Response) -> FoodProduct | None:
        try:
            payload = response.json()
        except ValueError as exc:
            raise FoodProviderInvalidResponseError from exc
        if not isinstance(payload, dict) or payload.get("status") == 0:
            return None
        product = payload.get("product")
        if not isinstance(product, dict):
            raise FoodProviderInvalidResponseError
        name = product.get("product_name")
        if not isinstance(name, str) or not name.strip():
            raise FoodProviderInvalidResponseError
        nutriments = product.get("nutriments")
        if not isinstance(nutriments, dict):
            raise FoodProviderInvalidResponseError
        values: dict[str, Decimal] = {}
        for output, keys in {
            "calories_kcal": ("energy-kcal_100g", "energy-kcal_value"),
            "protein_g": ("proteins_100g", "proteins_value"),
            "carbohydrate_g": ("carbohydrates_100g", "carbohydrates_value"),
            "fat_g": ("fat_100g", "fat_value"),
        }.items():
            raw = next(
                (nutriments.get(key) for key in keys if nutriments.get(key) is not None), None
            )
            try:
                values[output] = Decimal(str(raw))
            except (TypeError, ValueError, ArithmeticError) as exc:
                raise FoodProviderInvalidResponseError from exc
            if values[output] < 0:
                raise FoodProviderInvalidResponseError
        return FoodProduct(
            barcode=str(payload.get("code") or ""),
            name=name.strip(),
            brand=str(product.get("brands")).strip() if product.get("brands") else None,
            serving_description=str(product.get("serving_size") or "100 g"),
            nutrition=values,
            provider="open_food_facts",
            retrieved_at=datetime.now(UTC),
        )
