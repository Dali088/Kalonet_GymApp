import pytest

from kalonet_backend.core.security.password_policy import (
    is_common_or_breached_password,
    validate_new_password,
)
from kalonet_backend.core.security.passwords import (
    hash_password,
    verify_password,
)

TEST_PASSWORD = "correct-horse-battery-staple"


def test_hash_password_does_not_return_plaintext() -> None:
    encoded_hash = hash_password(TEST_PASSWORD)

    assert encoded_hash != TEST_PASSWORD
    assert encoded_hash.startswith("$argon2")
    assert verify_password(TEST_PASSWORD, encoded_hash)


def test_hash_password_uses_a_unique_salt() -> None:
    first_hash = hash_password(TEST_PASSWORD)
    second_hash = hash_password(TEST_PASSWORD)

    assert first_hash != second_hash
    assert verify_password(TEST_PASSWORD, first_hash)
    assert verify_password(TEST_PASSWORD, second_hash)


def test_verify_password_rejects_wrong_password() -> None:
    encoded_hash = hash_password(TEST_PASSWORD)

    assert not verify_password(
        "definitely-the-wrong-password",
        encoded_hash,
    )


def test_verify_password_rejects_unknown_hash_format() -> None:
    assert not verify_password(
        TEST_PASSWORD,
        "not-a-valid-password-hash",
    )


def test_password_blocklist_is_case_insensitive() -> None:
    assert is_common_or_breached_password("Password1234567")


def test_new_password_policy_rejects_blocklisted_password() -> None:
    with pytest.raises(ValueError, match="too common"):
        validate_new_password("password1234567")


def test_new_password_policy_allows_non_blocklisted_passphrase() -> None:
    password = "correct horse battery staple"

    assert validate_new_password(password) == password
