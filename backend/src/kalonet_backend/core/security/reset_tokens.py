from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe

from kalonet_backend.core.security.refresh_tokens import hash_opaque_token

RESET_TOKEN_RANDOM_BYTES = 32
DEFAULT_RESET_TOKEN_LIFETIME = timedelta(minutes=30)


@dataclass(frozen=True, slots=True)
class IssuedResetToken:
    """A one-time password-reset token and persistence values."""

    plain_token: str
    token_hash: str
    expires_at: datetime


def issue_reset_token(
    *,
    now: datetime | None = None,
    lifetime: timedelta = DEFAULT_RESET_TOKEN_LIFETIME,
) -> IssuedResetToken:
    """Generate a secure, expiring password-reset token."""

    if lifetime <= timedelta(0):
        raise ValueError("Reset-token lifetime must be positive.")

    issued_at = now or datetime.now(UTC)

    if issued_at.tzinfo is None:
        raise ValueError("The current time must include timezone information.")

    plain_token = token_urlsafe(RESET_TOKEN_RANDOM_BYTES)

    return IssuedResetToken(
        plain_token=plain_token,
        token_hash=hash_opaque_token(plain_token),
        expires_at=issued_at + lifetime,
    )
