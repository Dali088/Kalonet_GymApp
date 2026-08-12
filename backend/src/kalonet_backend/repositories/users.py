from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from kalonet_backend.models import User


class UserRepository:
    """Database operations for Kalonet users."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_email(self, email: str) -> User | None:
        statement = select(User).where(User.email == email)

        return self._session.scalar(statement)

    def get_by_email_for_update(self, email: str) -> User | None:
        """Find and lock one user for a user-scoped security transaction."""

        statement = select(User).where(User.email == email).with_for_update()

        return self._session.scalar(statement)

    def get_by_id(self, user_id: UUID) -> User | None:
        """Find one user by primary key."""

        return self._session.get(User, user_id)

    def get_by_id_for_update(self, user_id: UUID) -> User | None:
        """Find and lock one user for a password-change transaction."""

        statement = select(User).where(User.id == user_id).with_for_update()

        return self._session.scalar(statement)

    def create(
        self,
        *,
        email: str,
        password_hash: str,
    ) -> User:
        user = User(
            email=email,
            password_hash=password_hash,
        )

        self._session.add(user)
        self._session.flush()

        return user
