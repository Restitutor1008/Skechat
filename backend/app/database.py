import re
from collections.abc import Generator
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings, read_database_password


settings = get_settings()
engine = create_engine(settings.database_url, pool_pre_ping=True)


@event.listens_for(engine, "do_connect")
def _use_current_database_password(_, __, ___, connection_parameters):
    """Use a newly rotated password whenever the pool opens a connection."""
    connection_parameters["password"] = read_database_password()


SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def create_database_if_missing() -> None:
    if not re.fullmatch(r"[A-Za-z0-9_]+", settings.db_name):
        raise RuntimeError("DB_NAME contains unsupported characters")
    server_engine = create_engine(settings.server_database_url, pool_pre_ping=True)
    with server_engine.begin() as connection:
        connection.execute(
            text(
                f"CREATE DATABASE IF NOT EXISTS `{settings.db_name}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
        )
    server_engine.dispose()


def init_database() -> None:
    from . import models  # noqa: F401

    create_database_if_missing()
    backend_dir = Path(__file__).resolve().parents[1]
    alembic_config = Config(str(backend_dir / "alembic.ini"))
    command.upgrade(alembic_config, "head")
    Base.metadata.create_all(bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
