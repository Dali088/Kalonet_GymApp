from collections.abc import Callable
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from kalonet_backend.core.security import hash_opaque_token
from kalonet_backend.repositories import RefreshSessionRepository, UserRepository
from kalonet_backend.services.authentication import AuthenticationSessionResult
from kalonet_backend.services.authentication_tokens import AuthenticationTokenService


class InvalidRefreshTokenError(ValueError):
    """Raised when a refresh token cannot be used."""


class RefreshTokenReuseDetectedError(ValueError):
    """Raised when a previously rotated refresh token is presented again."""


def _utc_now() -> datetime:
    return datetime.now(UTC)


class RefreshTokenService:
    """Rotate refresh sessions inside one service-owned transaction."""

    def __init__(
        self,
        session: Session,
        token_service: AuthenticationTokenService,
        *,
        clock: Callable[[], datetime] = _utc_now,
    ) -> None:
        self._session = session
        self._token_service = token_service
        self._clock = clock
        self._refresh_sessions = RefreshSessionRepository(session)
        self._users = UserRepository(session)

    def rotate(self, *, refresh_token: str) -> AuthenticationSessionResult:
        """Consume one refresh token and issue its replacement."""

        now = self._clock()

        try:
            try:
                token_hash = hash_opaque_token(refresh_token)
            except ValueError as error:
                raise InvalidRefreshTokenError from error

            refresh_session = self._refresh_sessions.get_by_token_hash_for_update(
                token_hash,
            )

            if refresh_session is None:
                raise InvalidRefreshTokenError

            if refresh_session.rotated_at is not None:
                self._refresh_sessions.revoke_active_family(
                    family_id=refresh_session.family_id,
                    revoked_at=now,
                    revocation_reason="token_reuse",
                )
                self._session.commit()
                raise RefreshTokenReuseDetectedError

            if refresh_session.revoked_at is not None or refresh_session.expires_at <= now:
                raise InvalidRefreshTokenError

            user = self._users.get_by_id(refresh_session.user_id)

            if user is None:
                raise InvalidRefreshTokenError

            replacement_session_id = uuid4()
            issued_tokens = self._token_service.issue_session_tokens(
                user_id=user.id,
                session_id=replacement_session_id,
                now=now,
            )

            self._refresh_sessions.mark_rotated(
                refresh_session,
                rotated_at=now,
            )
            self._refresh_sessions.create(
                session_id=replacement_session_id,
                user_id=user.id,
                token_hash=issued_tokens.refresh_token_hash,
                family_id=refresh_session.family_id,
                expires_at=issued_tokens.refresh_token_expires_at,
                parent_session_id=refresh_session.id,
            )

            self._session.commit()

            return AuthenticationSessionResult(
                access_token=issued_tokens.access_token,
                refresh_token=issued_tokens.refresh_token,
                access_token_expires_in_seconds=(issued_tokens.access_token_expires_in_seconds),
                refresh_token_expires_at=issued_tokens.refresh_token_expires_at,
                user_id=user.id,
                email=user.email,
                onboarding_completed=(user.onboarding_completed_at is not None),
            )

        except RefreshTokenReuseDetectedError:
            raise
        except Exception:
            self._session.rollback()
            raise
