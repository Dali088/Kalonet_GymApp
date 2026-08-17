from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from kalonet_backend.core.security import (
    hash_password,
    verify_password_for_login,
)
from kalonet_backend.models import User
from kalonet_backend.repositories import (
    RefreshSessionRepository,
    UserRepository,
    UserSettingsRepository,
)
from kalonet_backend.services.authentication_tokens import (
    AuthenticationTokenService,
)


class EmailAlreadyRegisteredError(ValueError):
    """Raised when registration uses an existing email."""


class InvalidCredentialsError(ValueError):
    """Raised when login credentials cannot be authenticated."""


@dataclass(frozen=True, slots=True)
class AuthenticationSessionResult:
    """Successful authenticated-session result."""

    access_token: str
    refresh_token: str
    access_token_expires_in_seconds: int
    refresh_token_expires_at: datetime
    user_id: UUID
    email: str
    onboarding_completed: bool


def _create_authenticated_session(
    *,
    token_service: AuthenticationTokenService,
    refresh_sessions: RefreshSessionRepository,
    user: User,
) -> AuthenticationSessionResult:
    """Create the persisted refresh session and transport-neutral result."""

    session_id = uuid4()
    family_id = uuid4()

    issued_tokens = token_service.issue_session_tokens(
        user_id=user.id,
        session_id=session_id,
    )

    refresh_sessions.create(
        session_id=session_id,
        user_id=user.id,
        token_hash=issued_tokens.refresh_token_hash,
        family_id=family_id,
        expires_at=issued_tokens.refresh_token_expires_at,
    )

    return AuthenticationSessionResult(
        access_token=issued_tokens.access_token,
        refresh_token=issued_tokens.refresh_token,
        access_token_expires_in_seconds=(issued_tokens.access_token_expires_in_seconds),
        refresh_token_expires_at=(issued_tokens.refresh_token_expires_at),
        user_id=user.id,
        email=user.email,
        onboarding_completed=(user.onboarding_completed_at is not None),
    )


class RegistrationService:
    """Implement the EP1 account-registration use case."""

    def __init__(
        self,
        session: Session,
        token_service: AuthenticationTokenService,
    ) -> None:
        self._session = session
        self._token_service = token_service
        self._users = UserRepository(session)
        self._refresh_sessions = RefreshSessionRepository(session)
        self._settings = UserSettingsRepository(session)

    def register(
        self,
        *,
        email: str,
        password: str,
    ) -> AuthenticationSessionResult:
        existing_user = self._users.get_by_email(email)

        if existing_user is not None:
            raise EmailAlreadyRegisteredError

        try:
            user = self._users.create(
                email=email,
                password_hash=hash_password(password),
            )
            self._settings.get_or_create(user.id)

            result = _create_authenticated_session(
                token_service=self._token_service,
                refresh_sessions=self._refresh_sessions,
                user=user,
            )

            self._session.commit()

            return result

        except IntegrityError as error:
            self._session.rollback()

            # Protect against a registration race:
            # two requests may pass the initial lookup simultaneously.
            if self._users.get_by_email(email) is not None:
                raise EmailAlreadyRegisteredError from error

            raise

        except Exception:
            self._session.rollback()
            raise


class LoginService:
    """Implement the EP2 email/password login use case."""

    def __init__(
        self,
        session: Session,
        token_service: AuthenticationTokenService,
    ) -> None:
        self._session = session
        self._token_service = token_service
        self._users = UserRepository(session)
        self._refresh_sessions = RefreshSessionRepository(session)

    def login(
        self,
        *,
        email: str,
        password: str,
    ) -> AuthenticationSessionResult:
        user = self._users.get_by_email(email)

        if user is None:
            verify_password_for_login(password, None)
            raise InvalidCredentialsError

        if not verify_password_for_login(password, user.password_hash):
            raise InvalidCredentialsError

        try:
            result = _create_authenticated_session(
                token_service=self._token_service,
                refresh_sessions=self._refresh_sessions,
                user=user,
            )

            self._session.commit()

            return result

        except Exception:
            self._session.rollback()
            raise
