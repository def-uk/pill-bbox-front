from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from .api import VaultLimiter, router
from .config import Settings
from .db import create_db


class BodyLimit:
    """요청 본문이 [limit]바이트를 넘으면 413. Content-Length가 없는 요청도 읽으면서 센다.

    읽다가 넘으면 HTTPException을 던진다.
    FastAPI는 본문을 읽다 난 다른 예외를 400으로 바꾸기 때문이다.
    """

    def __init__(self, app: ASGIApp, limit: int) -> None:
        self.app = app
        self.limit = limit

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        length = dict(scope["headers"]).get(b"content-length")
        if length is not None and length.isdigit() and int(length) > self.limit:
            await self._reject(send)
            return

        received = 0

        async def counted() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.limit:
                    raise HTTPException(413, _TOO_LARGE)
            return message

        await self.app(scope, counted, send)

    async def _reject(self, send: Send) -> None:
        body = f'{{"detail":"{_TOO_LARGE}"}}'.encode()
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})


_TOO_LARGE = "요청이 너무 큽니다"


def create_app(settings: Settings | None = None) -> FastAPI:
    """`uvicorn app.main:create_app --factory`로 띄운다. 테스트는 설정을 넘겨 따로 만든다."""
    settings = settings or Settings()
    app = FastAPI(
        title="pillbbox 백엔드",
        description="사진 수집과 백업 (backend/README.md)",
        version="0.1.0",
    )
    app.state.settings = settings
    app.state.sessions = create_db(settings.database_url)
    app.state.vault_limiter = VaultLimiter(settings.vaults_per_hour)
    settings.samples_dir.mkdir(parents=True, exist_ok=True)

    app.include_router(router)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "commit": settings.commit}

    app.add_middleware(BodyLimit, limit=settings.max_backup_bytes)
    # 웹 앱(GitHub Pages)이 다른 출처에서 부른다. 412를 받고 리비전을 알려면 ETag를 읽어야 한다.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "If-Match"],
        expose_headers=["ETag"],
        max_age=600,
    )
    return app
