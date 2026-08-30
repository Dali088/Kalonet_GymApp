from io import BytesIO
from uuid import UUID

from PIL import Image, UnidentifiedImageError
from PIL.Image import DecompressionBombError
from sqlalchemy.orm import Session

from kalonet_backend.repositories import PersonalizationRepository, UserRepository

AVATAR_MAX_BYTES = 2 * 1024 * 1024
AVATAR_MAX_DIMENSION = 2048
AVATAR_CONTENT_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})


class InvalidAvatarError(ValueError):
    """Raised when an avatar is not a supported, bounded image."""


class AvatarNotFoundError(ValueError):
    """Raised when the authenticated user has no saved avatar."""


def validate_avatar(data: bytes, content_type: str | None) -> None:
    """Validate the declared and decoded image format before persistence."""

    if len(data) == 0 or len(data) > AVATAR_MAX_BYTES:
        raise InvalidAvatarError
    if content_type is None or content_type not in AVATAR_CONTENT_TYPES:
        raise InvalidAvatarError
    try:
        with Image.open(BytesIO(data)) as image:
            image.verify()
        with Image.open(BytesIO(data)) as image:
            format_to_content_type = {
                "JPEG": "image/jpeg",
                "PNG": "image/png",
                "WEBP": "image/webp",
            }
            image_format = image.format
            if image_format is None or format_to_content_type.get(image_format) != content_type:
                raise InvalidAvatarError
            if (
                image.width < 1
                or image.height < 1
                or image.width > AVATAR_MAX_DIMENSION
                or image.height > AVATAR_MAX_DIMENSION
            ):
                raise InvalidAvatarError
    except (
        DecompressionBombError,
        UnidentifiedImageError,
        OSError,
        SyntaxError,
        ValueError,
    ) as error:
        raise InvalidAvatarError from error


class ProfileAvatarService:
    """Coordinate authenticated avatar validation and profile persistence."""

    def __init__(self, session: Session) -> None:
        self._session = session
        self._users = UserRepository(session)
        self._personalization = PersonalizationRepository(session)

    def replace(self, user_id: UUID, data: bytes, content_type: str | None) -> None:
        validate_avatar(data, content_type)
        try:
            user = self._users.get_by_id(user_id)
            profile = self._personalization.get_profile(user_id, for_update=True)
            if user is None or profile is None or user.onboarding_completed_at is None:
                raise AvatarNotFoundError
            profile.avatar_bytes = data
            profile.avatar_content_type = content_type
            self._session.flush()
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise

    def remove(self, user_id: UUID) -> None:
        try:
            profile = self._personalization.get_profile(user_id, for_update=True)
            if profile is None:
                raise AvatarNotFoundError
            profile.avatar_bytes = None
            profile.avatar_content_type = None
            self._session.flush()
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise

    def get(self, user_id: UUID) -> tuple[bytes, str]:
        profile = self._personalization.get_profile(user_id)
        if profile is None or profile.avatar_bytes is None or profile.avatar_content_type is None:
            raise AvatarNotFoundError
        return profile.avatar_bytes, profile.avatar_content_type
