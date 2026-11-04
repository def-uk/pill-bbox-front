from io import BytesIO

from PIL import Image
from sqlalchemy import select

from app.models import Sample
from tests.conftest import jpeg, meta, upload


def stored(client) -> list[Sample]:
    with client.app.state.sessions() as session:
        return list(session.scalars(select(Sample)))


def test_upload_saves_photo_and_meta(client, auth, settings):
    sample = meta()

    response = upload(client, auth, sample)

    assert response.status_code == 201
    assert response.json() == {"id": sample["id"], "created": True}
    [row] = stored(client)
    assert row.model_version == "combofix-v1-fold1-w8"
    assert row.meta["boxes"][0]["from"] == "model"
    assert row.meta["boxes"][1]["final"] == {"category_id": None, "name": "비타민C"}
    assert (settings.samples_dir / row.photo_path).read_bytes()[:2] == b"\xff\xd8"


def test_same_id_twice_keeps_one(client, auth):
    sample = meta()
    upload(client, auth, sample)

    again = upload(client, auth, sample)

    assert again.status_code == 200
    assert again.json()["created"] is False
    assert len(stored(client)) == 1


def test_same_id_from_other_vault_is_409(client, auth):
    sample = meta()
    upload(client, auth, sample)
    other = {"Authorization": f"Bearer {client.post('/v1/vaults').json()['code']}"}

    assert upload(client, other, sample).status_code == 409


def test_exif_is_removed(client, auth, settings):
    exif = Image.Exif()
    exif[0x8825] = {2: (37.0, 33.0, 0.0)}  # GPS
    exif[0x010F] = "Apple"
    with_exif = jpeg(exif=exif.tobytes())
    assert Image.open(BytesIO(with_exif)).getexif()

    upload(client, auth, meta(), photo=with_exif)

    [row] = stored(client)
    saved = Image.open(settings.samples_dir / row.photo_path)
    assert not saved.getexif()
    assert saved.size == (640, 480)


def test_rotated_photo_is_422(client, auth):
    exif = Image.Exif()
    exif[0x0112] = 6
    response = upload(client, auth, meta(), photo=jpeg(exif=exif.tobytes()))

    assert response.status_code == 422
    assert "회전" in response.json()["detail"]


def test_not_jpeg_or_wrong_size_is_422(client, auth):
    png = BytesIO()
    Image.new("RGB", (640, 480)).save(png, "PNG")
    assert upload(client, auth, meta(), photo=png.getvalue()).status_code == 422
    assert upload(client, auth, meta(), photo=b"not an image").status_code == 422
    assert upload(client, auth, meta(), photo=jpeg(480, 640)).status_code == 422
    assert stored(client) == []


def test_inconsistent_boxes_are_422(client, auth):
    box = meta()["boxes"][0]
    cases = [
        box | {"box": [600, 88, 700, 140]},  # 사진 밖
        box | {"box": [171, 88, 102, 140]},  # x1 > x2
        box | {"final": None},  # removed가 아닌데 final 없음
        box | {"action": "picked"},  # model 박스는 picked가 아님
        box | {"from": "finder"},  # finder인데 predicted 있음
    ]
    for case in cases:
        response = upload(client, auth, meta(boxes=[case]))
        assert response.status_code == 422, case
        assert response.json()["detail"][0]["loc"][:2] == ["body", "meta"]


def test_photo_over_limit_is_413(client, auth, settings):
    settings.max_photo_bytes = 1000

    assert upload(client, auth, meta()).status_code == 413


def test_daily_limit(client, auth, settings):
    settings.samples_per_day = 2

    codes = [upload(client, auth, meta()).status_code for _ in range(3)]

    assert codes == [201, 201, 429]


def test_delete_samples_removes_files(client, auth, settings):
    upload(client, auth, meta())
    upload(client, auth, meta())
    other = {"Authorization": f"Bearer {client.post('/v1/vaults').json()['code']}"}
    upload(client, other, meta())

    response = client.delete("/v1/samples", headers=auth)

    assert response.json() == {"deleted": 2}
    assert len(stored(client)) == 1
    assert len(list(settings.samples_dir.rglob("*.jpg"))) == 1
