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
