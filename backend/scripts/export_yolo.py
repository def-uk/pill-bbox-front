"""모은 사진을 YOLO 학습 데이터로 내보낸다 (backend/README.md 4.5).

    uv run --env-file .env python -m scripts.export_yolo \\
        --labels ../frontend/assets/models/pillbox-<버전>.labels.json \\
        --out <폴더> [--since 2026-11-01]

<폴더>에 images/, labels/(YOLO txt), dataset.yaml, samples.csv, skipped.csv를 만든다.

- removed(약이 아님) 박스는 뺀다. 그 자리는 배경으로 학습한다.
- 96종 밖의 약이 하나라도 있는 사진은 통째로 뺀다.
  그 알약을 라벨 없이 두면 배경으로 배우기 때문이다.
- 박스는 사람이 그린 것이 아니다. 학습 전에 검수하고, 평가용 사진은 박스를 다시 그린다.
- samples.csv의 vault_id로 평가 데이터를 보관함(사용자) 단위로 나눈다.
"""

import argparse
import csv
import json
import shutil
from collections import Counter
from dataclasses import dataclass
from datetime import UTC, date, datetime, time
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.config import Settings
from app.db import create_db
from app.models import Sample


@dataclass
class Summary:
    exported: int
    skipped: int
    boxes: int


def export(
    sessions: sessionmaker[Session],
    samples_dir: Path,
    labels: list[dict],
    out: Path,
    since: date | None = None,
) -> Summary:
    yolo_idx = {label["category_id"]: label["yolo_idx"] for label in labels}
    (out / "images").mkdir(parents=True, exist_ok=True)
    (out / "labels").mkdir(parents=True, exist_ok=True)

    query = select(Sample).order_by(Sample.created_at)
    if since is not None:
        query = query.where(Sample.created_at >= datetime.combine(since, time(), UTC))

    exported, skipped, box_count = [], [], 0
    with sessions() as session:
        for sample in session.scalars(query):
            meta = sample.meta
            kept = [b for b in meta["boxes"] if b["action"] != "removed"]
            unknown = sorted(
                {b["final"]["name"] for b in kept if b["final"]["category_id"] not in yolo_idx}
            )
            if unknown:
                skipped.append((sample.id, "모델이 모르는 약: " + ", ".join(unknown)))
                continue

            width, height = meta["width"], meta["height"]
            lines = []
            for b in kept:
                x1, y1, x2, y2 = b["box"]
                lines.append(
                    f"{yolo_idx[b['final']['category_id']]} "
                    f"{(x1 + x2) / 2 / width:.6f} {(y1 + y2) / 2 / height:.6f} "
                    f"{(x2 - x1) / width:.6f} {(y2 - y1) / height:.6f}"
                )
            shutil.copyfile(samples_dir / sample.photo_path, out / "images" / f"{sample.id}.jpg")
            (out / "labels" / f"{sample.id}.txt").write_text("".join(f"{line}\n" for line in lines))
            box_count += len(lines)

            actions = Counter(b["action"] for b in meta["boxes"])
            exported.append(
                {
                    "id": sample.id,
                    "vault_id": sample.vault_id,
                    "model_version": sample.model_version,
                    "platform": sample.platform,
                    "captured_on": meta["captured_on"],
                    **{a: actions[a] for a in ("kept", "changed", "picked", "removed")},
                    "reviewed": sample.reviewed_at is not None,
                }
            )

    _write_csv(out / "samples.csv", exported)
    _write_csv(out / "skipped.csv", [{"id": i, "reason": r} for i, r in skipped])
    names = {label["yolo_idx"]: label["name"] for label in labels}
    (out / "dataset.yaml").write_text(
        "# 학습·평가 나누기는 samples.csv의 vault_id로 한다.\n"
        f"path: {out.resolve()}\n"
        "train: images\n"
        "val: images\n"
        "names:\n"
        + "".join(f"  {i}: {json.dumps(n, ensure_ascii=False)}\n" for i, n in sorted(names.items()))
    )
    return Summary(exported=len(exported), skipped=len(skipped), boxes=box_count)


def _write_csv(path: Path, rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        if not rows:
            return
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--labels", type=Path, required=True, help="모델의 labels.json")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--since", type=date.fromisoformat, help="이 날짜(UTC)부터 올라온 사진")
    args = parser.parse_args()

    settings = Settings()
    summary = export(
        create_db(settings.database_url),
        settings.samples_dir,
        json.loads(args.labels.read_text()),
        args.out,
        args.since,
    )
    print(
        f"사진 {summary.exported}장, 박스 {summary.boxes}개를 내보냈습니다. "
        f"{summary.skipped}장은 뺐습니다."
    )


if __name__ == "__main__":
    main()
