import mimetypes
import os

from starlette.applications import Starlette
from starlette.responses import Response
from starlette.routing import Mount
from starlette.staticfiles import StaticFiles
from starlette.types import Scope

from .config import Settings

mimetypes.add_type("application/octet-stream", ".onnx")


class WebFiles(StaticFiles):
    """Flutter 웹 빌드를 내보낸다. www.<도메인>이 터널로 여기에 온다 (backend/README.md 2장).

    대부분 파일 이름에 버전이 없어 매번 바뀌었는지 확인하게 한다(no-cache, ETag로 304).
    모델은 파일 이름에 버전이 들어가므로 오래 캐시한다.

    교차 출처 격리(COOP/COEP)를 켠다. 그래야 브라우저가 SharedArrayBuffer를 열어 주고,
    onnxruntime-web이 wasm 스레드 여러 개로 알약을 찾는다 (frontend/web/pill_detector_worker.js).
    require-corp라 다른 출처 파일은 CORP나 CORS 헤더가 있어야 읽힌다.
    지금 쓰는 jsDelivr(onnxruntime)와 gstatic(CanvasKit, 글꼴)은 둘 다 보낸다.
    """

    async def check_config(self) -> None:
        # 첫 웹 배포 전에는 폴더가 없다. 500 대신 404로 답한다.
        if self.directory is not None and os.path.isdir(self.directory):
            await super().check_config()

    def file_response(
        self, full_path: str | os.PathLike[str], stat_result: os.stat_result, scope: Scope, **kwargs
    ) -> Response:
        response = super().file_response(full_path, stat_result, scope, **kwargs)
        immutable = scope["path"].startswith("/assets/assets/models/")
        response.headers["Cache-Control"] = (
            "public, max-age=31536000, immutable" if immutable else "no-cache"
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return response


def create_app(settings: Settings | None = None) -> Starlette:
    """`uvicorn app.web:create_app --factory`로 띄운다. API(app.main)와 다른 프로세스다.

    current는 배포할 때마다 새 빌드를 가리키는 심볼릭 링크다. 요청마다 링크를 따라가므로
    배포 뒤에 다시 띄우지 않아도 된다. 아직 배포한 빌드가 없으면 404.
    """
    settings = settings or Settings()
    files = WebFiles(directory=settings.web_dir, html=True, check_dir=False)
    return Starlette(routes=[Mount("/", app=files)])
