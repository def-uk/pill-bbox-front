from collections.abc import Iterator
from pathlib import Path

from fastapi import Request
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from .models import Base


def create_db(url: str) -> sessionmaker[Session]:
    """SQLite를 열고 테이블이 없으면 만든다. 스키마가 바뀌는 2단계에서 Alembic을 넣는다."""
    if url.startswith("sqlite:///"):
        Path(url.removeprefix("sqlite:///")).parent.mkdir(parents=True, exist_ok=True)
    engine = create_engine(url, connect_args={"check_same_thread": False})
    event.listen(engine, "connect", _enable_foreign_keys)
    Base.metadata.create_all(engine)
    return sessionmaker(engine, expire_on_commit=False)


def _enable_foreign_keys(dbapi_connection, _record) -> None:
    dbapi_connection.execute("PRAGMA foreign_keys = ON")


def get_session(request: Request) -> Iterator[Session]:
    with request.app.state.sessions() as session:
        yield session
