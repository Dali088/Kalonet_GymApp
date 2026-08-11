from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest

from kalonet_backend.core.security.access_tokens import (
    InvalidAccessTokenError,
    create_access_token,
    decode_access_token,
)

TEST_SECRET = "kalonet-test-secret-key-with-at-least-32-bytes"


def test_access_token_round_trip() -> None:
    user_id = uuid4()
    session_id = uuid4()
    now = datetime.now(UTC)
    issued_at = now.replace(microsecond=0)

    token = create_access_token(
        user_id=user_id,
        session_id=session_id,
        secret_key=TEST_SECRET,
        now=now,
    )

    claims = decode_access_token(
        token,
        secret_key=TEST_SECRET,
        now=now,
    )

    assert claims.user_id == user_id
    assert claims.session_id == session_id
    assert claims.issued_at == issued_at
    assert claims.expires_at == issued_at + timedelta(minutes=15)


def test_access_token_rejects_wrong_secret() -> None:
    token = create_access_token(
        user_id=uuid4(),
        session_id=uuid4(),
        secret_key=TEST_SECRET,
    )

    with pytest.raises(InvalidAccessTokenError):
        decode_access_token(
            token,
            secret_key=("different-test-secret-key-with-32-bytes"),
        )


def test_access_token_rejects_expired_token() -> None:
    old_time = datetime(2020, 1, 1, tzinfo=UTC)

    token = create_access_token(
        user_id=uuid4(),
        session_id=uuid4(),
        secret_key=TEST_SECRET,
        now=old_time,
        lifetime=timedelta(minutes=15),
    )

    with pytest.raises(InvalidAccessTokenError):
        decode_access_token(
            token,
            secret_key=TEST_SECRET,
        )


def test_access_token_rejects_invalid_text() -> None:
    with pytest.raises(InvalidAccessTokenError):
        decode_access_token(
            "not-a-jwt",
            secret_key=TEST_SECRET,
        )


def test_access_token_rejects_short_secret() -> None:
    with pytest.raises(ValueError):
        create_access_token(
            user_id=uuid4(),
            session_id=uuid4(),
            secret_key="too-short",
        )
