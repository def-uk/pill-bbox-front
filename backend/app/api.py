import time
from collections import deque
from datetime import UTC, datetime
from datetime import time as day_start
from pathlib import Path
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import CurrentVault, hash_code, new_code
from .config import Settings
from .db import get_session
from .models import Backup, Sample, Vault, utcnow
from .photos import PhotoError, clean_jpeg
from .schemas import BackupOut, BackupSaved, Deleted, SampleMeta, SampleSaved, Snapshot

router = APIRouter(prefix="/v1")
DbSession = Annotated[Session, Depends(get_session)]


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


AppSettings = Annotated[Settings, Depends(get_settings)]


# 보관함 (backend/README.md 3.1)


class VaultLimiter:
    """서버 전체에서 최근 한 시간 동안 만든 보관함 수를 센다. 서버를 다시 띄우면 처음부터 센다."""

    def __init__(self, per_hour: int) -> None:
        self.per_hour = per_hour
        self._created: deque[float] = deque()

    def allow(self) -> bool:
        now = time.monotonic()
        while self._created and now - self._created[0] > 3600:
            self._created.popleft()
        if len(self._created) >= self.per_hour:
            return False
        self._created.append(now)
        return True


@router.post("/vaults", status_code=status.HTTP_201_CREATED)
def create_vault(request: Request, session: DbSession) -> dict[str, str]:
    """보관함을 만들고 동기화 코드를 돌려준다. 코드는 이때 한 번만 보여 준다."""
    if not request.app.state.vault_limiter.allow():
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "잠시 뒤에 다시 시도해 주세요")
    code = new_code()
    session.add(Vault(code_hash=hash_code(code)))
    session.commit()
    return {"code": code}


@router.delete("/vaults/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_vault(vault: CurrentVault, session: DbSession, settings: AppSettings) -> None:
    """보관함과 백업, 사진을 모두 지운다."""
    paths = _sample_paths(session, settings, vault)
    session.delete(vault)
    session.commit()
    _unlink(paths)


# 백업 (backend/README.md 3.2, 3.3)


def _latest_backup(session: Session, vault: Vault) -> Backup | None:
    return session.scalar(
        select(Backup).where(Backup.vault_id == vault.id).order_by(Backup.revision.desc()).limit(1)
    )


@router.get("/backup")
def get_backup(vault: CurrentVault, session: DbSession, response: Response) -> BackupOut:
    backup = _latest_backup(session, vault)
    if backup is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "아직 백업이 없습니다")
    response.headers["ETag"] = f'"{backup.revision}"'
    return BackupOut(
        revision=backup.revision,
        updated_at=backup.created_at,
        data=Snapshot.model_validate(backup.data),
    )


def _revision(if_match: str | None) -> int:
    """`If-Match: "3"`의 3. 처음 올릴 때는 `"0"`."""
    value = (if_match or "").strip().removeprefix("W/").strip('"')
    if not value:
        raise HTTPException(
            status.HTTP_428_PRECONDITION_REQUIRED,
            '지금 가진 리비전을 If-Match에 넣어 주세요. 처음 올릴 때는 "0"',
        )
    if not value.isdigit():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "If-Match는 리비전 숫자여야 합니다")
    return int(value)


@router.put("/backup")
def put_backup(
    snapshot: Snapshot,
    vault: CurrentVault,
    session: DbSession,
    settings: AppSettings,
    response: Response,
    if_match: Annotated[str | None, Header()] = None,
) -> BackupSaved:
    """백업을 통째로 바꾼다. 그사이 다른 기기가 올렸으면 412. 받아서 합친 뒤 다시 올린다."""
    expected = _revision(if_match)
    latest = _latest_backup(session, vault)
    current = latest.revision if latest else 0
    if expected != current:
        raise HTTPException(
            status.HTTP_412_PRECONDITION_FAILED,
            f"서버에 더 새로운 백업(리비전 {current})이 있습니다",
        )

    backup = Backup(
        vault_id=vault.id,
        revision=current + 1,
        data=snapshot.model_dump(mode="json", by_alias=True),
    )
    session.add(backup)
    try:
        session.flush()
    except IntegrityError:
        # 같은 리비전을 두 기기가 동시에 올렸다.
        session.rollback()
        raise HTTPException(
            status.HTTP_412_PRECONDITION_FAILED, "다른 기기가 방금 백업을 올렸습니다"
        ) from None

    keep_from = backup.revision - settings.backup_revisions_kept
    session.execute(delete(Backup).where(Backup.vault_id == vault.id, Backup.revision <= keep_from))
    session.commit()
    response.headers["ETag"] = f'"{backup.revision}"'
    return BackupSaved(revision=backup.revision, updated_at=backup.created_at)


# 사진 수집 (backend/README.md 4.2)


def _parse_meta(meta: str) -> SampleMeta:
    try:
        return SampleMeta.model_validate_json(meta)
    except ValidationError as e:
        raise RequestValidationError(
            [{**err, "loc": ("body", "meta", *err["loc"])} for err in e.errors(include_url=False)]
        ) from None


@router.post("/samples", status_code=status.HTTP_201_CREATED)
async def post_sample(
    photo: Annotated[UploadFile, File(description="긴 변 640px JPEG")],
    meta: Annotated[str, Form(description="backend/README.md 4.2의 JSON")],
    vault: CurrentVault,
    session: DbSession,
    settings: AppSettings,
    response: Response,
) -> SampleSaved:
    """사진 한 장과 라벨을 올린다. 같은 id를 다시 올리면 200으로 그대로 둔다."""
    sample_meta = _parse_meta(meta)
    sample_id = str(sample_meta.id)

    if (existing := session.get(Sample, sample_id)) is not None:
        if existing.vault_id != vault.id:
            raise HTTPException(status.HTTP_409_CONFLICT, "다른 보관함이 쓰는 id입니다")
        response.status_code = status.HTTP_200_OK
        return SampleSaved(id=sample_meta.id, created=False)

    today = datetime.combine(utcnow().date(), day_start(), UTC)
    uploaded_today = session.scalar(
        select(func.count()).where(Sample.vault_id == vault.id, Sample.created_at >= today)
    )
    if uploaded_today >= settings.samples_per_day:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "오늘 올릴 수 있는 사진을 다 올렸습니다"
        )

    data = await photo.read(settings.max_photo_bytes + 1)
    if len(data) > settings.max_photo_bytes:
        raise HTTPException(
            status.HTTP_413_CONTENT_TOO_LARGE,
            f"사진은 {settings.max_photo_bytes:,}바이트 이하여야 합니다",
        )
    try:
        data = clean_jpeg(data, sample_meta.width, sample_meta.height)
    except PhotoError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(e)) from None

    now = utcnow()
    relative = f"{now:%Y-%m}/{sample_id}.jpg"
    path = settings.samples_dir / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)

    session.add(
        Sample(
            id=sample_id,
            vault_id=vault.id,
            model_version=sample_meta.model_version,
            platform=sample_meta.platform,
            meta=sample_meta.model_dump(mode="json", by_alias=True),
            photo_path=relative,
            created_at=now,
        )
    )
    try:
        session.commit()
    except IntegrityError:
        # 같은 사진을 동시에 두 번 올렸다. 먼저 들어간 쪽이 같은 파일을 쓴다.
        session.rollback()
        if (
            existing := session.get(Sample, sample_id)
        ) is not None and existing.vault_id == vault.id:
            response.status_code = status.HTTP_200_OK
            return SampleSaved(id=sample_meta.id, created=False)
        path.unlink(missing_ok=True)
        raise HTTPException(status.HTTP_409_CONFLICT, "다른 보관함이 쓰는 id입니다") from None
    return SampleSaved(id=sample_meta.id, created=True)


def _sample_paths(session: Session, settings: Settings, vault: Vault) -> list[Path]:
    relatives = session.scalars(select(Sample.photo_path).where(Sample.vault_id == vault.id))
    return [settings.samples_dir / r for r in relatives]


def _unlink(paths: list[Path]) -> None:
    """DB에서 지운 뒤에 파일을 지운다. 커밋이 실패하면 사진이 남는 쪽이 낫다."""
    for path in paths:
        path.unlink(missing_ok=True)


@router.delete("/samples")
def delete_samples(vault: CurrentVault, session: DbSession, settings: AppSettings) -> Deleted:
    """이 보관함이 올린 사진을 모두 지운다."""
    paths = _sample_paths(session, settings, vault)
    session.execute(delete(Sample).where(Sample.vault_id == vault.id))
    session.commit()
    _unlink(paths)
    return Deleted(deleted=len(paths))
