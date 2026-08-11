from datetime import UTC, datetime, timedelta

import pytest

from kalonet_backend.core.security.refresh_tokens import (
    hash_opaque_token,
    issue_refresh_token,
)


def test_issue_refresh_token_returns_plain_and_hashed_values() -> None:
    now = datetime.now(UTC)

    issued = issue_refresh_token(now=now)

    assert issued.plain_token
    assert issued.token_hash != issued.plain_token
    assert len(issued.token_hash) == 64
    assert issued.token_hash == hash_opaque_token(issued.plain_token)
    assert issued.expires_at == now + timedelta(days=30)


def test_refresh_tokens_are_unique() -> None:
    first = issue_refresh_token()
    second = issue_refresh_token()

    assert first.plain_token != second.plain_token
    assert first.token_hash != second.token_hash


def test_hash_opaque_token_is_deterministic() -> None:
    token = "example-refresh-token"

    assert hash_opaque_token(token) == hash_opaque_token(token)


def test_hash_opaque_token_rejects_empty_value() -> None:
    with pytest.raises(ValueError):
        hash_opaque_token("")


def test_issue_refresh_token_rejects_non_positive_lifetime() -> None:
    with pytest.raises(ValueError):
        issue_refresh_token(lifetime=timedelta(0))
