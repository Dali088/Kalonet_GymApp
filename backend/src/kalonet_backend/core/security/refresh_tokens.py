from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from secrets import token_urlsafe

REFRESH_TOKEN_RANDOM_BYTES = 32
DEFAULT_REFRESH_TOKEN_LIFETIME = timedelta(days=30)


@dataclass(frozen=True, slots=True)
class IssuedRefreshToken:
    """A refresh token and the values needed for persistence."""

    plain_token: str
    token_hash: str
    expires_at: datetime


def hash_opaque_token(token: str) -> str:
    """Hash an opaque token before database storage or lookup."""

    if not token:
        raise ValueError("Token must not be empty.")

    return sha256(token.encode("utf-8")).hexdigest()


def issue_refresh_token(
    *,
    now: datetime | None = None,
    lifetime: timedelta = DEFAULT_REFRESH_TOKEN_LIFETIME,
) -> IssuedRefreshToken:
    """Generate a secure refresh token and its persistence values."""

    if lifetime <= timedelta(0):
        raise ValueError("Refresh-token lifetime must be positive.")

    issued_at = now or datetime.now(UTC)

    if issued_at.tzinfo is None:
        raise ValueError("The current time must include timezone information.")

    plain_token = token_urlsafe(REFRESH_TOKEN_RANDOM_BYTES)

    return IssuedRefreshToken(
        plain_token=plain_token,
        token_hash=hash_opaque_token(plain_token),
        expires_at=issued_at + lifetime,
    )
