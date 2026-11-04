"""약 찾기와 약 정보 (backend/README.md 3.5). 식약처 API를 대신 불러 인증키를 앱에 두지 않는다."""

import threading
import time
from collections import OrderedDict
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Request, Response, status

from .api import VaultLimiter
from .mfds import DrugInfoSource, DrugSourceError
from .schemas import DrugDetail, DrugPage

router = APIRouter(prefix="/v1/drugs", tags=["drugs"])

PER_PAGE = 20
ItemSeq = Annotated[str, Path(pattern=r"^\d{1,20}$", description="품목기준코드")]


class TtlCache:
    """오래된 것부터 버리는 시간 제한 캐시. 같은 약을 여러 사람이 찾아도 식약처는 한 번만 부른다."""

    def __init__(self, seconds: float, max_items: int) -> None:
        self.seconds = seconds
        self.max_items = max_items
        self._items: OrderedDict[Any, tuple[float, Any]] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: Any) -> tuple[bool, Any]:
        with self._lock:
            hit = self._items.get(key)
            if hit is None or hit[0] < time.monotonic():
                self._items.pop(key, None)
                return False, None
            self._items.move_to_end(key)
            return True, hit[1]

    def put(self, key: Any, value: Any) -> None:
        with self._lock:
            self._items[key] = (time.monotonic() + self.seconds, value)
            self._items.move_to_end(key)
            while len(self._items) > self.max_items:
                self._items.popitem(last=False)


class Drugs:
    """캐시에 없을 때만 식약처를 부르고, 부른 횟수를 시간당 [calls_per_hour]로 막는다.

    공공데이터포털 개발 계정은 하루 호출 수가 정해져 있다.
    웹은 누구나 열 수 있으므로 서버에서 막는다.
    """

    def __init__(
        self, source: DrugInfoSource | None, calls_per_hour: int, cache_seconds: float
    ) -> None:
        self.source = source
        self._limiter = VaultLimiter(calls_per_hour)
        self._cache = TtlCache(cache_seconds, max_items=2000)
        self._images = TtlCache(cache_seconds, max_items=300)

    def search(self, query: str, page: int) -> DrugPage:
        return self._cached(
            self._cache, ("search", query, page), lambda s: s.search(query, page, PER_PAGE)
        )

    def detail(self, item_seq: str) -> DrugDetail | None:
        return self._cached(self._cache, ("detail", item_seq), lambda s: s.detail(item_seq))

    def image(self, item_seq: str) -> tuple[bytes, str] | None:
        return self._cached(self._images, item_seq, lambda s: s.image(item_seq))

    def _cached(self, cache: TtlCache, key: Any, call):
        if self.source is None:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE, "약 정보 서비스를 켜지 않았습니다"
            )
        hit, value = cache.get(key)
        if hit:
            return value
        if not self._limiter.allow():
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "잠시 뒤에 다시 시도해 주세요")
        try:
            value = call(self.source)
        except DrugSourceError as e:
            raise HTTPException(
                status.HTTP_502_BAD_GATEWAY, f"식약처에서 답을 받지 못했습니다 ({e})"
            ) from None
        cache.put(key, value)
        return value


def get_drugs(request: Request) -> Drugs:
    return request.app.state.drugs


AppDrugs = Annotated[Drugs, Depends(get_drugs)]


@router.get("")
def search_drugs(
    drugs: AppDrugs,
    q: Annotated[str, Query(min_length=1, max_length=50, description="약 이름 일부")],
    page: Annotated[int, Query(ge=1, le=50)] = 1,
) -> DrugPage:
    """이름으로 약을 찾는다 (낱알식별). 한 쪽에 20개."""
    query = q.strip()
    if not query:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "약 이름을 넣어 주세요")
    return drugs.search(query, page)


@router.get("/{item_seq}")
def get_drug(drugs: AppDrugs, item_seq: ItemSeq) -> DrugDetail:
    """낱알식별과 e약은요를 합친 약 정보. 둘 다 없으면 404."""
    detail = drugs.detail(item_seq)
    if detail is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "식약처에 없는 약입니다")
    return detail


@router.get("/{item_seq}/image", response_class=Response)
def get_drug_image(drugs: AppDrugs, item_seq: ItemSeq) -> Response:
    """낱알 사진.

    웹은 교차 출처 격리(COEP)를 켜서 의약품안전나라 사진을 바로 못 읽으므로 대신 받아 준다.
    """
    image = drugs.image(item_seq)
    if image is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "사진이 없습니다")
    body, content_type = image
    return Response(
        body,
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=604800",
            "Cross-Origin-Resource-Policy": "cross-origin",
        },
    )
