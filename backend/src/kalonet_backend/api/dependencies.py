from typing import Annotated

from fastapi import Depends, Header

from kalonet_backend.core.config import Settings, get_settings
from kalonet_backend.core.security import (
    AccessTokenClaims,
    InvalidAccessTokenError,
    decode_access_token,
)


def get_current_access_token_claims(
    settings: Annotated[Settings, Depends(get_settings)],
    authorization: Annotated[str | None, Header()] = None,
) -> AccessTokenClaims:
    """Validate the bearer access token for a protected request."""

    if authorization is None:
        raise InvalidAccessTokenError

    parts = authorization.split()

    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise InvalidAccessTokenError

    return decode_access_token(
        parts[1],
        secret_key=settings.jwt_secret_key.get_secret_value(),
    )
