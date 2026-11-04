import json
import uuid
from io import BytesIO

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.config import Settings
from app.main import create_app


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        database_url=f"sqlite:///{tmp_path}/test.db",
        samples_dir=tmp_path / "samples",
        commit="abc123",
    )


@pytest.fixture
def client(settings) -> TestClient:
    return TestClient(create_app(settings))


@pytest.fixture
def auth(client) -> dict[str, str]:
    code = client.post("/v1/vaults").json()["code"]
    return {"Authorization": f"Bearer {code}"}


def jpeg(width: int = 640, height: int = 480, **save_options) -> bytes:
    out = BytesIO()
    Image.new("RGB", (width, height), (200, 180, 160)).save(out, "JPEG", **save_options)
    return out.getvalue()


def meta(**overrides) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "model_version": "combofix-v1-fold1-w8",
        "platform": "web",
        "app_version": "0.1.0+1",
        "captured_on": "2026-11-04",
        "width": 640,
        "height": 480,
        "boxes": [
            {
                "box": [102, 88, 171, 140],
                "from": "model",
                "predicted": {
                    "category_id": 250,
                    "confidence": 0.81,
                    "alternatives": [{"category_id": 1899, "confidence": 0.62}],
                },
                "final": {"category_id": 1899, "name": "다른약"},
                "action": "changed",
            },
            {
                "box": [300, 210, 352, 251],
                "from": "finder",
                "predicted": None,
                "final": {"category_id": None, "name": "비타민C"},
                "action": "picked",
            },
            {
                "box": [410, 60, 470, 115],
                "from": "model",
                "predicted": {"category_id": 250, "confidence": 0.55},
                "final": None,
                "action": "removed",
            },
        ],
    } | overrides


def upload(client: TestClient, auth: dict, sample: dict, photo: bytes | None = None):
    return client.post(
        "/v1/samples",
        headers=auth,
        data={"meta": json.dumps(sample)},
        files={"photo": ("photo.jpg", photo if photo is not None else jpeg(), "image/jpeg")},
    )
