from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import RefreshSession


class RefreshSessionRepository:
    """Database operations for refresh sessions."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def create(
        self,
        *,
        session_id: UUID,
        user_id: UUID,
        token_hash: str,
        family_id: UUID,
        expires_at: datetime,
        parent_session_id: UUID | None = None,
    ) -> RefreshSession:
        refresh_session = RefreshSession(
            id=session_id,
            user_id=user_id,
            token_hash=token_hash,
            family_id=family_id,
            expires_at=expires_at,
            parent_session_id=parent_session_id,
        )

        self._session.add(refresh_session)
        self._session.flush()

        return refresh_session

    def get_by_token_hash_for_update(
        self,
        token_hash: str,
    ) -> RefreshSession | None:
        """Find and lock one refresh session for a rotation transaction."""

        statement = (
            select(RefreshSession).where(RefreshSession.token_hash == token_hash).with_for_update()
        )

        return self._session.scalar(statement)

    def get_by_token_hash(
        self,
        token_hash: str,
    ) -> RefreshSession | None:
        """Find one refresh session without taking a row lock."""

        statement = select(RefreshSession).where(RefreshSession.token_hash == token_hash)

        return self._session.scalar(statement)

    def mark_rotated(
        self,
        refresh_session: RefreshSession,
        *,
        rotated_at: datetime,
    ) -> None:
        """Mark a consumed refresh session without committing the transaction."""

        refresh_session.rotated_at = rotated_at
        self._session.flush()

    def revoke_session(
        self,
        refresh_session: RefreshSession,
        *,
        revoked_at: datetime,
        revocation_reason: str,
    ) -> None:
        """Revoke one session without committing the transaction."""

        if not revocation_reason:
            raise ValueError("Revocation reason must not be empty.")

        if refresh_session.revoked_at is None:
            refresh_session.revoked_at = revoked_at
            refresh_session.revocation_reason = revocation_reason
            self._session.flush()

    def revoke_active_family(
        self,
        *,
        family_id: UUID,
        revoked_at: datetime,
        revocation_reason: str,
    ) -> int:
        """Revoke and return the number of active sessions in one token family."""

        if not revocation_reason:
            raise ValueError("Revocation reason must not be empty.")

        statement = (
            select(RefreshSession)
            .where(
                RefreshSession.family_id == family_id,
                RefreshSession.rotated_at.is_(None),
                RefreshSession.revoked_at.is_(None),
            )
            .with_for_update()
        )
        active_sessions = list(self._session.scalars(statement))

        for refresh_session in active_sessions:
            refresh_session.revoked_at = revoked_at
            refresh_session.revocation_reason = revocation_reason

        self._session.flush()

        return len(active_sessions)

    def revoke_active_for_user(
        self,
        *,
        user_id: UUID,
        revoked_at: datetime,
        revocation_reason: str,
    ) -> int:
        """Revoke every currently unrevoked session owned by one user."""

        if not revocation_reason:
            raise ValueError("Revocation reason must not be empty.")

        statement = (
            select(RefreshSession)
            .where(
                RefreshSession.user_id == user_id,
                RefreshSession.revoked_at.is_(None),
            )
            .with_for_update()
        )
        active_sessions = list(self._session.scalars(statement))

        for refresh_session in active_sessions:
            refresh_session.revoked_at = revoked_at
            refresh_session.revocation_reason = revocation_reason

        self._session.flush()

        return len(active_sessions)
