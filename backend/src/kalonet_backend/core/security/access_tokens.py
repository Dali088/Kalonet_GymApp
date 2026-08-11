from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import jwt
from jwt.exceptions import InvalidTokenError

ACCESS_TOKEN_ALGORITHM = "HS256"
DEFAULT_ACCESS_TOKEN_LIFETIME = timedelta(minutes=15)
MINIMUM_SECRET_KEY_BYTES = 32


class InvalidAccessTokenError(ValueError):
    """Raised when an access token cannot be trusted."""


@dataclass(frozen=True, slots=True)
class AccessTokenClaims:
    """Validated claims extracted from an access token."""

    user_id: UUID
    session_id: UUID
    token_id: UUID
    issued_at: datetime
    expires_at: datetime


def create_access_token(
    *,
    user_id: UUID,
    session_id: UUID,
    secret_key: str,
    now: datetime | None = None,
    lifetime: timedelta = DEFAULT_ACCESS_TOKEN_LIFETIME,
) -> str:
    """Create a signed JWT access token."""

    _validate_secret_key(secret_key)

    if lifetime <= timedelta(0):
        raise ValueError("Access-token lifetime must be positive.")

    issued_at = now or datetime.now(UTC)

    if issued_at.tzinfo is None:
        raise ValueError("The current time must include timezone information.")

    expires_at = issued_at + lifetime

    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "jti": str(uuid4()),
        "token_type": "access",
        "iat": issued_at,
        "exp": expires_at,
    }

    return jwt.encode(
        payload,
        secret_key,
        algorithm=ACCESS_TOKEN_ALGORITHM,
    )


def decode_access_token(
    token: str,
    *,
    secret_key: str,
    now: datetime | None = None,
) -> AccessTokenClaims:
    """Validate and decode a JWT access token."""

    _validate_secret_key(secret_key)

    if not token:
        raise InvalidAccessTokenError("Access token must not be empty.")

    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            secret_key,
            algorithms=[ACCESS_TOKEN_ALGORITHM],
            options={
                "require": [
                    "sub",
                    "sid",
                    "jti",
                    "token_type",
                    "iat",
                    "exp",
                ],
                "verify_exp": False,
            },
        )
    except InvalidTokenError as error:
        raise InvalidAccessTokenError("Access token is invalid.") from error

    if payload.get("token_type") != "access":
        raise InvalidAccessTokenError("Token is not an access token.")

    try:
        user_id = UUID(str(payload["sub"]))
        session_id = UUID(str(payload["sid"]))
        token_id = UUID(str(payload["jti"]))
        issued_at = datetime.fromtimestamp(
            int(payload["iat"]),
            tz=UTC,
        )
        expires_at = datetime.fromtimestamp(
            int(payload["exp"]),
            tz=UTC,
        )
    except (KeyError, TypeError, ValueError) as error:
        raise InvalidAccessTokenError("Access-token claims are invalid.") from error

    current_time = now or datetime.now(UTC)

    if current_time.tzinfo is None:
        raise ValueError("The current time must include timezone information.")

    if expires_at <= current_time:
        raise InvalidAccessTokenError("Access token has expired.")

    return AccessTokenClaims(
        user_id=user_id,
        session_id=session_id,
        token_id=token_id,
        issued_at=issued_at,
        expires_at=expires_at,
    )


def _validate_secret_key(secret_key: str) -> None:
    if len(secret_key.encode("utf-8")) < MINIMUM_SECRET_KEY_BYTES:
        raise ValueError("JWT secret key must contain at least 32 bytes.")
