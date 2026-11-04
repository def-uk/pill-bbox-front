from datetime import date, datetime
from typing import Annotated, Literal, Self
from uuid import UUID

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    NonNegativeFloat,
    PositiveInt,
    StringConstraints,
    model_validator,
)

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
Confidence = Annotated[float, Field(ge=0, le=1)]


class _Model(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)


# 백업 (backend/README.md 3.2). 엑셀 백업의 세 시트를 그대로 옮긴다.


class BackupMedication(_Model):
    name: Name
    category_id: int | None
    dose_per_take: PositiveInt
    times: list[Annotated[str, StringConstraints(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")]]


class BackupRecord(_Model):
    taken_at: AwareDatetime
    medication: Name
    count: PositiveInt
    source: Literal["camera", "manual"]


class BackupAppearance(_Model):
    medication: Name
    l: float  # noqa: E741  CIELAB의 L
    a: float
    b: float
    elongation: Annotated[float, Field(gt=0)]


class Snapshot(_Model):
    version: Literal[1] = Field(alias="schema")
    exported_at: AwareDatetime
    medications: list[BackupMedication]
    records: list[BackupRecord]
    appearances: list[BackupAppearance]

    @model_validator(mode="after")
    def _medications_exist(self) -> Self:
        names = {m.name for m in self.medications}
        used = {r.medication for r in self.records} | {a.medication for a in self.appearances}
        if unknown := used - names:
            raise ValueError(f"medications에 없는 약: {', '.join(sorted(unknown))}")
        return self


class BackupOut(_Model):
    revision: int
    updated_at: datetime
    data: Snapshot


class BackupSaved(_Model):
    revision: int
    updated_at: datetime


# 사진 수집 (backend/README.md 4.2).


class Alternative(_Model):
    category_id: int
    confidence: Confidence


class Predicted(_Model):
    category_id: int
    confidence: Confidence
    alternatives: list[Alternative] = []


class FinalLabel(_Model):
    # 96종 밖에서 직접 등록한 약은 null.
    category_id: int | None
    name: Name


class SampleBox(_Model):
    box: tuple[NonNegativeFloat, NonNegativeFloat, NonNegativeFloat, NonNegativeFloat]
    source: Literal["model", "finder"] = Field(alias="from")
    predicted: Predicted | None
    final: FinalLabel | None
    action: Literal["kept", "changed", "picked", "removed"]

    @model_validator(mode="after")
    def _consistent(self) -> Self:
        x1, y1, x2, y2 = self.box
        if not (x1 < x2 and y1 < y2):
            raise ValueError("box는 [x1, y1, x2, y2]이고 x1 < x2, y1 < y2여야 합니다")
        if (self.final is None) != (self.action == "removed"):
            raise ValueError("final은 action이 removed일 때만 비어 있습니다")
        if (self.predicted is None) != (self.source == "finder"):
            raise ValueError("predicted는 from이 finder일 때만 비어 있습니다")
        if self.source == "finder" and self.action in ("kept", "changed"):
            raise ValueError("finder 박스의 action은 picked나 removed입니다")
        if self.source == "model" and self.action == "picked":
            raise ValueError("model 박스의 action은 kept, changed, removed입니다")
        return self


class SampleMeta(_Model):
    id: UUID
    model_version: Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9._-]{1,100}$")]
    platform: Literal["web", "android", "ios"]
    app_version: Annotated[str, StringConstraints(max_length=50)]
    captured_on: date
    width: PositiveInt
    height: PositiveInt
    boxes: Annotated[list[SampleBox], Field(max_length=200)]

    @model_validator(mode="after")
    def _boxes_inside(self) -> Self:
        for i, b in enumerate(self.boxes):
            _, _, x2, y2 = b.box
            if x2 > self.width or y2 > self.height:
                raise ValueError(f"boxes[{i}]가 사진({self.width}×{self.height}) 밖에 있습니다")
        return self


class SampleSaved(_Model):
    id: UUID
    created: bool


class Deleted(_Model):
    deleted: int
