from uuid import UUID

from sqlalchemy.orm import Session

from kalonet_backend.core.security import verify_password_for_login
from kalonet_backend.repositories import UserRepository
from kalonet_backend.services.password_change import CurrentPasswordIncorrectError


class AccountDeletionService:
    """Permanently delete the authenticated user and database-owned dependants."""

    def __init__(self, session: Session) -> None:
        self._session = session
        self._users = UserRepository(session)

    def delete(self, *, user_id: UUID, current_password: str) -> None:
        try:
            user = self._users.get_by_id_for_update(user_id)
            if user is None or not verify_password_for_login(current_password, user.password_hash):
                raise CurrentPasswordIncorrectError
            self._session.delete(user)
            self._session.flush()
            self._session.commit()
        except Exception:
            self._session.rollback()
            raise
