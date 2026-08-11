MIN_PASSWORD_LENGTH = 15
MAX_PASSWORD_LENGTH = 128

# This is a small, locally maintained denylist of passwords that are widely
# used or routinely found in breach corpora.  It is intentionally kept in the
# application so registration does not send candidate passwords to a remote
# password-checking service.
COMMON_OR_BREACHED_PASSWORDS = frozenset(
    {
        "123456789012345",
        "1234567890",
        "password1234567",
        "password123",
        "password1",
        "password",
        "p@ssword123456",
        "qwerty1234567",
        "qwerty123",
        "qwerty",
        "letmein1234567",
        "letmein",
        "welcome1234567",
        "welcome",
        "changeme123456",
        "changeme",
        "admin123456789",
        "admin",
        "iloveyou123456",
        "iloveyou",
        "correcthorsebatterystaple",
    }
)


def is_common_or_breached_password(password: str) -> bool:
    """Return whether a password matches the local denylist.

    ``casefold`` makes the comparison case-insensitive without trimming or
    otherwise changing the password that will be stored after hashing.
    """

    return password.casefold() in COMMON_OR_BREACHED_PASSWORDS


def validate_new_password(password: str) -> str:
    """Validate a password being created or changed."""

    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must contain at least {MIN_PASSWORD_LENGTH} characters.")

    if len(password) > MAX_PASSWORD_LENGTH:
        raise ValueError(f"Password must contain at most {MAX_PASSWORD_LENGTH} characters.")

    if password.isspace():
        raise ValueError("Password must contain at least one non-whitespace character.")

    if is_common_or_breached_password(password):
        raise ValueError(
            "Password is too common or has appeared in a known data breach."
        )

    return password
