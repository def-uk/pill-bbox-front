import json

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.mfds import EASY_URL, GRN_URL, DrugSourceError, MfdsSource, parse_items

PILL = {
    "ITEM_SEQ": "200808876",
    "ITEM_NAME": "가스디알정50밀리그램(디메크로틴산마그네슘)",
    "ENTP_NAME": "일동제약(주)",
    "CHART": "녹색의 원형 필름코팅정",
    "ITEM_IMAGE": "https://nedrug.mfds.go.kr/pbp/cmn/itemImageDownload/147426403087300104",
    "PRINT_FRONT": "IDG",
    "PRINT_BACK": None,
    "DRUG_SHAPE": "원형",
    "COLOR_CLASS1": "초록",
    "COLOR_CLASS2": None,
    "LENG_LONG": "7.6",
    "LENG_SHORT": "7.6",
    "THICK": "3.5",
    "CLASS_NAME": "제산제",
    "ETC_OTC_NAME": "일반의약품",
    "FORM_CODE_NAME": "필름코팅정",
}
EASY = {
    "itemSeq": "200808876",
    "itemName": "가스디알정50밀리그램(디메크로틴산마그네슘)",
    "entpName": "일동제약(주)",
    "efcyQesitm": "<p>이 약은 위산과다, 속쓰림에 사용합니다.</p>",
    "useMethodQesitm": "1회 1정, 1일 3회 복용합니다.\n",
    "atpnWarnQesitm": None,
    "atpnQesitm": "이 약에 과민증 환자는 복용하지 마십시오.",
    "intrcQesitm": None,
    "seQesitm": "변비가 나타날 수 있습니다.",
    "depositMethodQesitm": "실온에서 보관하십시오.",
    "updateDe": "2024-05-09",
    "itemImage": None,
}


def envelope(items, total=None) -> bytes:
    return json.dumps(
        {
            "header": {"resultCode": "00", "resultMsg": "NORMAL SERVICE."},
            "body": {
                "pageNo": 1,
                "totalCount": len(items) if total is None else total,
                "numOfRows": 20,
                "items": items,
            },
        }
    ).encode()


class FakeHttp:
    def __init__(self, grn=(PILL,), easy=(EASY,)):
        self.grn = list(grn)
        self.easy = list(easy)
        self.calls: list[tuple[str, dict | None]] = []

    def __call__(self, url, params):
        self.calls.append((url, params))
        if url == GRN_URL:
            if "item_seq" in params:
                return envelope([i for i in self.grn if i["ITEM_SEQ"] == params["item_seq"]]), ""
            return envelope(self.grn, total=42), "application/json"
        if url == EASY_URL:
            return envelope([i for i in self.easy if i["itemSeq"] == params["itemSeq"]]), ""
        return b"\xff\xd8jpeg", "image/jpeg"


def test_search_maps_pill_fields():
    http = FakeHttp()
    page = MfdsSource("key+/=", fetch=http).search("가스디알", 1, 20)

    assert page.total == 42
    [drug] = page.items
    assert drug.item_seq == "200808876"
    assert drug.company == "일동제약(주)"
    assert drug.otc == "일반의약품"
    assert drug.colors == ["초록"]
    assert drug.print_front == "IDG"
    assert drug.has_image
    url, params = http.calls[0]
    assert params["serviceKey"] == "key+/=" and params["type"] == "json"
    assert params["item_name"] == "가스디알"


def test_detail_merges_pill_and_guide():
    detail = MfdsSource("k", fetch=FakeHttp()).detail("200808876")

    assert detail.chart == "녹색의 원형 필름코팅정"
    assert detail.length_long == 7.6
    assert detail.guide.efficacy == "이 약은 위산과다, 속쓰림에 사용합니다."
    assert detail.guide.usage == "1회 1정, 1일 3회 복용합니다."
    assert detail.guide.warning is None


def test_detail_without_guide_or_pill():
    source = MfdsSource("k", fetch=FakeHttp(easy=()))
    assert source.detail("200808876").guide is None

    only_guide = MfdsSource("k", fetch=FakeHttp(grn=())).detail("200808876")
    assert only_guide.name.startswith("가스디알정")
    assert only_guide.chart is None
    assert not only_guide.has_image

    assert MfdsSource("k", fetch=FakeHttp(grn=(), easy=())).detail("1") is None


def test_image_only_from_mfds_hosts():
    assert MfdsSource("k", fetch=FakeHttp()).image("200808876") == (b"\xff\xd8jpeg", "image/jpeg")

    elsewhere = {**PILL, "ITEM_IMAGE": "https://example.com/a.jpg"}
    http = FakeHttp(grn=(elsewhere,))
    assert MfdsSource("k", fetch=http).image("200808876") is None
    assert all(url != "https://example.com/a.jpg" for url, _ in http.calls)


@pytest.mark.parametrize(
    "items",
    [
        [PILL],
        {"item": [PILL]},
        {"item": PILL},
    ],
)
def test_parse_items_shapes(items):
    body = json.dumps(
        {"response": {"header": {"resultCode": "00"}, "body": {"items": items, "totalCount": 1}}}
    )
    assert parse_items(body.encode()) == ([PILL], 1)


def test_parse_items_empty_and_errors():
    assert parse_items(envelope("")) == ([], 0)

    xml = (
        b"<OpenAPI_ServiceResponse><cmmMsgHeader>"
        b"<returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg>"
        b"</cmmMsgHeader></OpenAPI_ServiceResponse>"
    )
    with pytest.raises(DrugSourceError, match="SERVICE_KEY_IS_NOT_REGISTERED_ERROR"):
        parse_items(xml)

    failed = json.dumps({"header": {"resultCode": "30", "resultMsg": "등록되지 않은 키"}}).encode()
    with pytest.raises(DrugSourceError, match="30"):
        parse_items(failed)


# API


@pytest.fixture
def http() -> FakeHttp:
    return FakeHttp()


@pytest.fixture
def drug_client(settings, http) -> TestClient:
    return TestClient(create_app(settings, drug_source=MfdsSource("k", fetch=http)))


def test_search_and_detail_api(drug_client, http):
    res = drug_client.get("/v1/drugs", params={"q": " 가스디알 "})
    assert res.status_code == 200
    assert res.json()["items"][0]["item_seq"] == "200808876"
    assert http.calls[0][1]["item_name"] == "가스디알"

    res = drug_client.get("/v1/drugs/200808876")
    assert res.status_code == 200
    assert res.json()["guide"]["storage"] == "실온에서 보관하십시오."

    assert drug_client.get("/v1/drugs/999").status_code == 404
    assert drug_client.get("/v1/drugs/abc").status_code == 422
    assert drug_client.get("/v1/drugs", params={"q": "  "}).status_code == 422


def test_image_api_headers(drug_client):
    res = drug_client.get("/v1/drugs/200808876/image")
    assert res.status_code == 200
    assert res.headers["content-type"] == "image/jpeg"
    assert res.headers["cross-origin-resource-policy"] == "cross-origin"


def test_results_are_cached(drug_client, http):
    drug_client.get("/v1/drugs/200808876")
    calls = len(http.calls)
    drug_client.get("/v1/drugs/200808876")
    assert len(http.calls) == calls


def test_upstream_limit(settings, http):
    settings.drug_calls_per_hour = 1
    client = TestClient(create_app(settings, drug_source=MfdsSource("k", fetch=http)))
    assert client.get("/v1/drugs", params={"q": "a"}).status_code == 200
    assert client.get("/v1/drugs", params={"q": "a"}).status_code == 200  # 캐시
    assert client.get("/v1/drugs", params={"q": "b"}).status_code == 429


def test_upstream_error_is_502(settings):
    def broken(url, params):
        raise DrugSourceError("연결 안 됨")

    client = TestClient(create_app(settings, drug_source=MfdsSource("k", fetch=broken)))
    res = client.get("/v1/drugs", params={"q": "a"})
    assert res.status_code == 502
    assert "연결 안 됨" in res.json()["detail"]


def test_off_without_key(client):
    assert client.get("/v1/drugs", params={"q": "a"}).status_code == 503
