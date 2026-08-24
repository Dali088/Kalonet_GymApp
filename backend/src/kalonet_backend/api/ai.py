from typing import Annotated

from fastapi import APIRouter, Depends, File, Request, UploadFile, status
from fastapi.responses import JSONResponse

from kalonet_backend.api.dependencies import get_current_access_token_claims
from kalonet_backend.api.errors import build_error_response
from kalonet_backend.core.config import Settings, get_settings
from kalonet_backend.core.security import AccessTokenClaims
from kalonet_backend.schemas.meal_photo import (
    MealPhotoAnalysisResponse,
    MealPhotoItemResponse,
    MealPhotoNutrition,
)
from kalonet_backend.services.meal_photo import (
    GeminiMealPhotoProvider,
    MealPhotoAnalysis,
    MealPhotoInvalidImageError,
    MealPhotoLowConfidenceError,
    MealPhotoNoFoodDetectedError,
    MealPhotoProvider,
    MealPhotoProviderInvalidResponseError,
    MealPhotoProviderRateLimitedError,
    MealPhotoProviderUnavailableError,
    MealPhotoService,
    MealPhotoTooLargeError,
)

router = APIRouter(prefix="/api/v1", tags=["AI"])


def get_meal_photo_provider(
    request: Request, settings: Annotated[Settings, Depends(get_settings)]
) -> MealPhotoProvider:
    provider = getattr(request.app.state, "meal_photo_provider", None)
    return provider or GeminiMealPhotoProvider(settings)


def _error(request: Request, status_code: int, code: str, message: str) -> JSONResponse:
    return build_error_response(
        request=request, status_code=status_code, code=code, message=message
    )


@router.post("/ai/meal-photo-analyses", response_model=MealPhotoAnalysisResponse)
async def analyze_meal_photo(
    request: Request,
    image: Annotated[UploadFile, File(...)],
    claims: Annotated[AccessTokenClaims, Depends(get_current_access_token_claims)],
    provider: Annotated[MealPhotoProvider, Depends(get_meal_photo_provider)],
) -> MealPhotoAnalysisResponse | JSONResponse:
    del claims
    image_bytes = await image.read(5 * 1024 * 1024 + 1)
    try:
        analysis = MealPhotoService(provider).analyze(image_bytes, image.content_type or "")
    except MealPhotoInvalidImageError:
        return _error(
            request,
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "invalid_image",
            "The uploaded file is not a supported image.",
        )
    except MealPhotoTooLargeError:
        return _error(
            request,
            status.HTTP_413_CONTENT_TOO_LARGE,
            "image_too_large",
            "The image must be 5 MiB or smaller.",
        )
    except MealPhotoNoFoodDetectedError:
        return _error(
            request,
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "ai_no_food_detected",
            "No food could be identified in the image.",
        )
    except MealPhotoLowConfidenceError:
        return _error(
            request,
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "ai_low_confidence",
            "The image result is too uncertain. Please use manual entry.",
        )
    except MealPhotoProviderRateLimitedError:
        return _error(
            request,
            status.HTTP_429_TOO_MANY_REQUESTS,
            "ai_provider_rate_limited",
            "The AI provider is rate-limited. Please try again later.",
        )
    except MealPhotoProviderInvalidResponseError:
        return _error(
            request,
            status.HTTP_502_BAD_GATEWAY,
            "ai_provider_invalid_response",
            "The AI provider returned unusable data.",
        )
    except MealPhotoProviderUnavailableError:
        return _error(
            request,
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "ai_provider_unavailable",
            "AI analysis is temporarily unavailable. Use manual entry.",
        )
    finally:
        await image.close()
    return _response(analysis)


def _response(analysis: MealPhotoAnalysis) -> MealPhotoAnalysisResponse:
    return MealPhotoAnalysisResponse(
        items=[
            MealPhotoItemResponse(
                name=item.name,
                estimated_grams=item.estimated_grams,
                confidence=item.confidence,
                nutrition=MealPhotoNutrition(**item.nutrition),
            )
            for item in analysis.items
        ],
        overall_confidence=analysis.overall_confidence,
        disclaimer=analysis.disclaimer,
    )
