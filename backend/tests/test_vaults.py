import re

from app.auth import normalize
from tests.conftest import jpeg, meta, upload


def test_health(client):
    assert client.get("/health").json() == {"status": "ok", "commit": "abc123"}


def test_new_vault_returns_grouped_code(client):
    response = client.post("/v1/vaults")

    assert response.status_code == 201
    assert re.fullmatch(
        r"([0-9A-HJKMNP-TV-Z]{4}-){4}[0-9A-HJKMNP-TV-Z]{4}", response.json()["code"]
    )


def test_backup_without_code_is_401(client):
    assert client.get("/v1/backup").status_code == 401
    assert client.get("/v1/backup", headers={"Authorization": "Bearer nope"}).status_code == 401
    unknown = "Bearer 0000-0000-0000-0000-0000"
    assert client.get("/v1/backup", headers={"Authorization": unknown}).status_code == 401


def test_code_typed_by_hand_still_works(client):
    code = client.post("/v1/vaults").json()["code"]
    typed = code.replace("-", " ").lower().replace("1", "l").replace("0", "o")

    response = client.get("/v1/backup", headers={"Authorization": f"Bearer {typed}"})

    assert response.status_code == 404  # 인증은 통과하고 백업이 아직 없다


def test_normalize_rejects_wrong_length_and_letters():
    assert normalize("ABCD") is None
    assert normalize("UUUU-UUUU-UUUU-UUUU-UUUU") is None


def test_vault_creation_is_rate_limited(settings):
    from fastapi.testclient import TestClient

    from app.main import create_app

    settings.vaults_per_hour = 2
    client = TestClient(create_app(settings))

    assert [client.post("/v1/vaults").status_code for _ in range(3)] == [201, 201, 429]


def test_delete_vault_removes_backup_and_photos(client, auth, settings):
    upload(client, auth, meta())
    photos = list(settings.samples_dir.rglob("*.jpg"))
    assert len(photos) == 1

    assert client.delete("/v1/vaults/me", headers=auth).status_code == 204

    assert not photos[0].exists()
    assert client.get("/v1/backup", headers=auth).status_code == 401


def test_body_over_limit_is_413(settings):
    from fastapi.testclient import TestClient

    from app.main import create_app

    settings.max_backup_bytes = 1000
    client = TestClient(create_app(settings))
    auth = {"Authorization": f"Bearer {client.post('/v1/vaults').json()['code']}"}

    response = upload(client, auth, meta(), photo=jpeg())

    assert response.status_code == 413
