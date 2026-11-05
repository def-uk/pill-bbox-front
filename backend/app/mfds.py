"""식약처 공공데이터포털 의약품 API (backend/README.md 3.5).

- 낱알식별 (MdcinGrnIdntfcInfoService03): 알약 모양·색·각인·크기·사진. 이름으로 찾기도 여기서 한다.
- e약은요 (DrbEasyDrugInfoService): 효능·사용법·주의사항·부작용·보관법. 주로 일반의약품만 있다.

두 API는 품목기준코드(item_seq)로 잇는다. 인증키는 공공데이터포털의 일반 인증키(Decoding)다.
"""

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from typing import Protocol

from .schemas import DrugDetail, DrugGuide, DrugPage, DrugSummary

GRN_URL = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03"
EASY_URL = "https://apis.data.go.kr/1471000/DrbEasyDrugInfoService/getDrbEasyDrugList"

# 낱알 사진은 의약품안전나라에 있다. 응답에 든 주소라도 이 밖으로는 받지 않는다.
IMAGE_HOSTS = frozenset({"nedrug.mfds.go.kr"})
MAX_IMAGE_BYTES = 2_000_000


class DrugSourceError(Exception):
    """식약처 서버가 답하지 않거나 오류로 답했다."""


class DrugInfoSource(Protocol):
    def search(self, query: str, page: int, per_page: int) -> DrugPage: ...

    def detail(self, item_seq: str) -> DrugDetail | None: ...

    def image(self, item_seq: str) -> tuple[bytes, str] | None: ...


# (주소, 쿼리) → (본문, Content-Type). 테스트는 가짜를 넘긴다.
Fetch = Callable[[str, dict[str, str | int] | None], tuple[bytes, str]]


def urllib_fetch(
    url: str, params: dict[str, str | int] | None, timeout: float = 10
) -> tuple[bytes, str]:
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": "pillbbox-backend"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read(MAX_IMAGE_BYTES + 1)
            if len(body) > MAX_IMAGE_BYTES:
                raise DrugSourceError("응답이 너무 큽니다")
            return body, response.headers.get("Content-Type", "")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise DrugSourceError(f"식약처 서버에 연결하지 못했습니다: {e}") from None


class MfdsSource:
    def __init__(self, service_key: str, fetch: Fetch = urllib_fetch) -> None:
        self._key = service_key
        self._fetch = fetch

    def search(self, query: str, page: int, per_page: int) -> DrugPage:
        items, total = self._call(
            GRN_URL, {"item_name": query, "pageNo": page, "numOfRows": per_page}
        )
        return DrugPage(
            total=total,
            page=page,
            items=[_summary(item) for item in items if _text(item.get("ITEM_SEQ"))],
        )

    def detail(self, item_seq: str) -> DrugDetail | None:
        pill = self._grn(item_seq)
        easy = self._easy(item_seq)
        if pill is None and easy is None:
            return None
        guide = _guide(easy) if easy else None
        if pill is not None:
            return DrugDetail(
                **_summary(pill).model_dump(),
                chart=_text(pill.get("CHART")),
                form=_text(pill.get("FORM_CODE_NAME")),
                class_name=_text(pill.get("CLASS_NAME")),
                length_long=_number(pill.get("LENG_LONG")),
                length_short=_number(pill.get("LENG_SHORT")),
                thickness=_number(pill.get("THICK")),
                guide=guide,
            )
        assert easy is not None
        return DrugDetail(
            item_seq=item_seq,
            name=_text(easy.get("itemName")) or item_seq,
            company=_text(easy.get("entpName")),
            has_image=_image_url(easy.get("itemImage")) is not None,
            guide=guide,
        )

    def image(self, item_seq: str) -> tuple[bytes, str] | None:
        pill = self._grn(item_seq)
        url = _image_url(pill.get("ITEM_IMAGE")) if pill else None
        if url is None and (easy := self._easy(item_seq)):
            url = _image_url(easy.get("itemImage"))
        if url is None:
            return None
        body, content_type = self._fetch(url, None)
        if not content_type.startswith("image/"):
            raise DrugSourceError(f"사진이 아닌 응답입니다: {content_type}")
        return body, content_type

    def _grn(self, item_seq: str) -> dict | None:
        items, _ = self._call(GRN_URL, {"item_seq": item_seq, "pageNo": 1, "numOfRows": 1})
        return next((i for i in items if _text(i.get("ITEM_SEQ")) == item_seq), None)

    def _easy(self, item_seq: str) -> dict | None:
        items, _ = self._call(EASY_URL, {"itemSeq": item_seq, "pageNo": 1, "numOfRows": 1})
        return next((i for i in items if _text(i.get("itemSeq")) == item_seq), None)

    def _call(self, url: str, params: dict[str, str | int]) -> tuple[list[dict], int]:
        body, _ = self._fetch(url, {"serviceKey": self._key, "type": "json", **params})
        return parse_items(body)


def parse_items(body: bytes) -> tuple[list[dict], int]:
    """공공데이터포털 응답에서 (items, totalCount). 키가 틀리면 type=json이어도 XML로 답한다."""
    try:
        data = json.loads(body)
    except ValueError:
        raise DrugSourceError(f"식약처 오류: {_xml_error(body)}") from None
    if not isinstance(data, dict):
        raise DrugSourceError("알 수 없는 응답 형식입니다")
    data = data.get("response", data)
    header = data.get("header") or {}
    code = str(header.get("resultCode", "00"))
    if code not in ("00", "0"):
        raise DrugSourceError(f"식약처 오류 {code}: {header.get('resultMsg', '')}")
    body_part = data.get("body") or {}
    items = body_part.get("items") or []
    if isinstance(items, dict):
        items = items.get("item") or []
    if isinstance(items, dict):
        items = [items]
    total = body_part.get("totalCount") or 0
    return [i for i in items if isinstance(i, dict)], int(total)


def _xml_error(body: bytes) -> str:
    text = body.decode("utf-8", "replace")
    for tag in ("returnAuthMsg", "errMsg", "resultMsg"):
        if m := re.search(rf"<{tag}>(.*?)</{tag}>", text, re.S):
            return m.group(1).strip()
    return text[:200].strip() or "빈 응답"


_TAG = re.compile(r"<[^>]+>")


def _text(value: object) -> str | None:
    if value is None:
        return None
    text = _TAG.sub("", str(value)).strip()
    return text or None


def _number(value: object) -> float | None:
    try:
        return float(str(value).strip())
    except ValueError:
        return None


def _image_url(value: object) -> str | None:
    url = _text(value)
    if url is None:
        return None
    parsed = urllib.parse.urlparse(url)
    return url if parsed.scheme == "https" and parsed.hostname in IMAGE_HOSTS else None


def _summary(item: dict) -> DrugSummary:
    colors = [c for c in (_text(item.get("COLOR_CLASS1")), _text(item.get("COLOR_CLASS2"))) if c]
    return DrugSummary(
        item_seq=_text(item.get("ITEM_SEQ")) or "",
        name=_text(item.get("ITEM_NAME")) or "",
        company=_text(item.get("ENTP_NAME")),
        otc=_text(item.get("ETC_OTC_NAME")),
        shape=_text(item.get("DRUG_SHAPE")),
        colors=colors,
        print_front=_text(item.get("PRINT_FRONT")),
        print_back=_text(item.get("PRINT_BACK")),
        has_image=_image_url(item.get("ITEM_IMAGE")) is not None,
    )


def _guide(item: dict) -> DrugGuide:
    return DrugGuide(
        efficacy=_text(item.get("efcyQesitm")),
        usage=_text(item.get("useMethodQesitm")),
        warning=_text(item.get("atpnWarnQesitm")),
        caution=_text(item.get("atpnQesitm")),
        interaction=_text(item.get("intrcQesitm")),
        side_effect=_text(item.get("seQesitm")),
        storage=_text(item.get("depositMethodQesitm")),
        updated_on=_text(item.get("updateDe")),
    )
