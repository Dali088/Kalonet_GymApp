from datetime import UTC, datetime, timedelta
from uuid import uuid4

from kalonet_backend.core.config import Settings
from kalonet_backend.core.security import (
    decode_access_token,
    hash_opaque_token,
)
from kalonet_backend.services.authentication_tokens import (
    AuthenticationTokenService,
)

TEST_SECRET = "test-jwt-secret-key-containing-at-least-32-bytes"


def create_test_settings() -> Settings:
    return Settings(
        environment="test",
        jwt_secret_key=TEST_SECRET,
        access_token_lifetime_seconds=600,
        refresh_token_lifetime_days=14,
    )


def test_token_service_uses_configured_lifetimes() -> None:
    now = datetime.now(UTC)
    user_id = uuid4()
    session_id = uuid4()

    service = AuthenticationTokenService(create_test_settings())

    issued = service.issue_session_tokens(
        user_id=user_id,
        session_id=session_id,
        now=now,
    )

    assert issued.access_token_expires_in_seconds == 600
    assert issued.refresh_token_expires_at == (now + timedelta(days=14))


def test_token_service_returns_matching_refresh_hash() -> None:
    service = AuthenticationTokenService(create_test_settings())

    issued = service.issue_session_tokens(
        user_id=uuid4(),
        session_id=uuid4(),
    )

    assert issued.refresh_token_hash == hash_opaque_token(issued.refresh_token)


def test_token_service_creates_access_token_for_session() -> None:
    now = datetime.now(UTC)
    issued_at = now.replace(microsecond=0)
    user_id = uuid4()
    session_id = uuid4()

    service = AuthenticationTokenService(create_test_settings())

    issued = service.issue_session_tokens(
        user_id=user_id,
        session_id=session_id,
        now=now,
    )

    claims = decode_access_token(
        issued.access_token,
        secret_key=TEST_SECRET,
    )

    assert claims.user_id == user_id
    assert claims.session_id == session_id
    assert claims.issued_at == issued_at
    assert claims.expires_at == issued_at + timedelta(seconds=600)


def test_token_service_never_returns_plaintext_as_hash() -> None:
    service = AuthenticationTokenService(create_test_settings())

    issued = service.issue_session_tokens(
        user_id=uuid4(),
        session_id=uuid4(),
    )

    assert issued.refresh_token
    assert issued.refresh_token_hash
    assert issued.refresh_token != issued.refresh_token_hash
