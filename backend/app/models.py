from datetime import UTC, datetime
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, String, TypeDecorator, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def utcnow() -> datetime:
    return datetime.now(UTC)


class UTCDateTime(TypeDecorator[datetime]):
    """UTC로 저장하고 UTC로 읽는다. SQLite는 시간대를 저장하지 않아 읽으면 시간대가 빠진다."""

    impl = DateTime
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect) -> datetime | None:
        return value.astimezone(UTC).replace(tzinfo=None) if value is not None else None

    def process_result_value(self, value: datetime | None, dialect) -> datetime | None:
        return value.replace(tzinfo=UTC) if value is not None else None


class Base(DeclarativeBase):
    type_annotation_map = {datetime: UTCDateTime, dict[str, Any]: JSON}


class Vault(Base):
    """동기화 코드 하나로 쓰는 보관함. 코드는 SHA-256만 저장한다."""

    __tablename__ = "vaults"

    id: Mapped[int] = mapped_column(primary_key=True)
    code_hash: Mapped[str] = mapped_column(String(64), unique=True)
    created_at: Mapped[datetime] = mapped_column(default=utcnow)


class Backup(Base):
    """기기 데이터 전체(backend/README.md 3.2). 보관함마다 최근 리비전 몇 개만 남긴다."""

    __tablename__ = "backups"
    __table_args__ = (UniqueConstraint("vault_id", "revision"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    vault_id: Mapped[int] = mapped_column(ForeignKey("vaults.id", ondelete="CASCADE"), index=True)
    revision: Mapped[int]
    data: Mapped[dict[str, Any]]
    created_at: Mapped[datetime] = mapped_column(default=utcnow)


class Sample(Base):
    """수집한 사진 한 장과 라벨(backend/README.md 4.2). 사진 파일은 DB 밖에 둔다."""

    __tablename__ = "samples"

    # 앱이 만든 UUID. 다시 올려도 한 장으로 남는다.
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    vault_id: Mapped[int] = mapped_column(ForeignKey("vaults.id", ondelete="CASCADE"), index=True)
    model_version: Mapped[str] = mapped_column(String(100))
    platform: Mapped[str] = mapped_column(String(10))
    meta: Mapped[dict[str, Any]]

    # samples_dir 기준 상대 경로.
    photo_path: Mapped[str] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(default=utcnow, index=True)
    reviewed_at: Mapped[datetime | None]
