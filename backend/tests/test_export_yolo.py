import csv

from scripts.export_yolo import export
from tests.conftest import meta, upload

LABELS = [
    {"yolo_idx": 0, "category_id": 250, "name": "타이레놀정500mg"},
    {"yolo_idx": 1, "category_id": 1899, "name": "다른약"},
]


def box(**fields) -> dict:
    return {
        "box": [64, 48, 128, 96],
        "from": "model",
        "predicted": {"category_id": 250, "confidence": 0.9},
        "final": {"category_id": 250, "name": "타이레놀정500mg"},
        "action": "kept",
    } | fields


def test_export_writes_yolo_labels(client, auth, settings, tmp_path):
    kept = meta(boxes=[box(), box(box=[300, 210, 352, 251], final=None, action="removed")])
    changed = meta(boxes=[box(final={"category_id": 1899, "name": "다른약"}, action="changed")])
    unknown = meta()  # 96종 밖의 약(비타민C)이 있다
    for sample in (kept, changed, unknown):
        assert upload(client, auth, sample).status_code == 201
    out = tmp_path / "export"

    summary = export(client.app.state.sessions, settings.samples_dir, LABELS, out)

    assert (summary.exported, summary.skipped, summary.boxes) == (2, 1, 2)
    # 640×480 사진의 [64, 48, 128, 96] → 가운데 (96, 72), 크기 64×48
    assert (out / "labels" / f"{kept['id']}.txt").read_text() == (
        "0 0.150000 0.150000 0.100000 0.100000\n"
    )
    assert (out / "labels" / f"{changed['id']}.txt").read_text().startswith("1 ")
    assert (out / "images" / f"{kept['id']}.jpg").exists()
    assert not (out / "images" / f"{unknown['id']}.jpg").exists()

    with (out / "skipped.csv").open() as f:
        [row] = list(csv.DictReader(f))
    assert row["id"] == unknown["id"]
    assert "비타민C" in row["reason"]
    with (out / "samples.csv").open() as f:
        rows = {r["id"]: r for r in csv.DictReader(f)}
    assert rows[kept["id"]]["removed"] == "1"
    assert '0: "타이레놀정500mg"' in (out / "dataset.yaml").read_text()
