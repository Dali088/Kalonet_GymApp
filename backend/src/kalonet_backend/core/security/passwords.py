from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError

_password_hasher = PasswordHash.recommended()

# Used only to make unknown-email login attempts perform the same kind of
# password-hash work as known-email attempts.  It is not a user credential.
_dummy_login_password_hash = _password_hasher.hash(
    "kalonet-login-timing-dummy",
)


def hash_password(plain_password: str) -> str:
    """Create a secure password hash for database storage."""

    return _password_hasher.hash(plain_password)


def verify_password(
    plain_password: str,
    encoded_hash: str,
) -> bool:
    """Return whether a plaintext password matches a stored hash."""

    try:
        return _password_hasher.verify(
            plain_password,
            encoded_hash,
        )
    except UnknownHashError:
        return False


def verify_password_for_login(
    plain_password: str,
    encoded_hash: str | None,
) -> bool:
    """Verify login credentials without exposing whether the email exists."""

    return verify_password(
        plain_password,
        encoded_hash or _dummy_login_password_hash,
    )
