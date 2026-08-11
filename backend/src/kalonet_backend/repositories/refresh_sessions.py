from datetime import datetime
from uuid import UUID

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
    ) -> RefreshSession:
        refresh_session = RefreshSession(
            id=session_id,
            user_id=user_id,
            token_hash=token_hash,
            family_id=family_id,
            expires_at=expires_at,
        )

        self._session.add(refresh_session)
        self._session.flush()

        return refresh_session
