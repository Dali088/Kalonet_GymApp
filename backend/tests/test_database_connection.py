from sqlalchemy import Engine, text


def test_database_connection(
    database_engine: Engine,
) -> None:
    with database_engine.connect() as connection:
        result = connection.execute(text("SELECT current_database(), current_user")).one()

    assert result.current_database == "kalonet"
    assert result.current_user == "kalonet"
