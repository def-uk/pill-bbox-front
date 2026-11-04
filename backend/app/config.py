from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """서버 설정. `PILLBBOX_` 접두사 환경 변수나 `--env-file`로 바꾼다 (backend/README.md 5.1)."""

    model_config = SettingsConfigDict(env_prefix="PILLBBOX_")

    database_url: str = "sqlite:///data/pillbbox.db"
    samples_dir: Path = Path("data/samples")

    # 쉼표로 나눈 웹 주소. 경로 없이 scheme + host.
    cors_origins: str = "http://localhost:8080"

    # /health에 보여 줄 커밋. 배포 스크립트가 넣는다.
    commit: str = "dev"

    # POST /v1/vaults는 누구나 부를 수 있으므로 서버 전체에서 시간당 개수를 막는다.
    vaults_per_hour: int = 30

    # 보관함 하나가 하루(UTC)에 올릴 수 있는 사진 수.
    samples_per_day: int = 300
    max_photo_bytes: int = 1_000_000

    # 백업 JSON. 기록 1만 건이 1MB 남짓이다.
    max_backup_bytes: int = 5_000_000

    # 보관함마다 남겨 두는 백업 리비전 수. 잘못 덮어썼을 때 맥미니에서 직접 되살린다.
    backup_revisions_kept: int = 10

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]
