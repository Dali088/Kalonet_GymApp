from sqlalchemy import text

from kalonet_backend.core.config import Settings
from kalonet_backend.db.session import create_database_engine


def test_database_connection() -> None:
    settings = Settings(
        environment="test",
        database_url=("postgresql+psycopg://kalonet:kalonet_local_password@localhost:5433/kalonet"),
    )
    engine = create_database_engine(settings)

    with engine.connect() as connection:
        result = connection.execute(text("SELECT current_database(), current_user")).one()

    assert result.current_database == "kalonet"
    assert result.current_user == "kalonet"

    engine.dispose()
