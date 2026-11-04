from fastapi.testclient import TestClient

from app.web import create_app


def release(root, name: str, index: str):
    folder = root / "releases" / name
    (folder / "assets/assets/models").mkdir(parents=True)
    (folder / "index.html").write_text(index)
    (folder / "sqlite3.wasm").write_bytes(b"\0asm")
    (folder / "assets/assets/models/pillbox-v1.onnx").write_bytes(b"model")
    return folder


def point_current(root, folder):
    current = root / "current"
    current.unlink(missing_ok=True)
    current.symlink_to(folder)


def test_404_before_first_deploy(settings):
    settings.web_dir = settings.samples_dir.parent / "web" / "current"

    assert TestClient(create_app(settings)).get("/").status_code == 404


def test_serves_build_with_cache_headers(settings, tmp_path):
    root = tmp_path / "web"
    root.mkdir()
    point_current(root, release(root, "a", "<html>a</html>"))
    settings.web_dir = root / "current"
    client = TestClient(create_app(settings))

    index = client.get("/")
    assert index.text == "<html>a</html>"
    assert index.headers["cache-control"] == "no-cache"
    assert client.get("/sqlite3.wasm").headers["content-type"] == "application/wasm"
    model = client.get("/assets/assets/models/pillbox-v1.onnx")
    assert "immutable" in model.headers["cache-control"]


def test_enables_cross_origin_isolation_for_wasm_threads(settings, tmp_path):
    root = tmp_path / "web"
    root.mkdir()
    point_current(root, release(root, "a", "a"))
    settings.web_dir = root / "current"
    client = TestClient(create_app(settings))

    for path in ["/", "/assets/assets/models/pillbox-v1.onnx"]:
        headers = client.get(path).headers
        assert headers["cross-origin-opener-policy"] == "same-origin"
        assert headers["cross-origin-embedder-policy"] == "require-corp"


def test_new_release_is_served_without_restart(settings, tmp_path):
    root = tmp_path / "web"
    root.mkdir()
    point_current(root, release(root, "a", "a"))
    settings.web_dir = root / "current"
    client = TestClient(create_app(settings))
    assert client.get("/").text == "a"

    point_current(root, release(root, "b", "b"))

    assert client.get("/").text == "b"


def test_cannot_escape_build_folder(settings, tmp_path):
    root = tmp_path / "web"
    root.mkdir()
    point_current(root, release(root, "a", "a"))
    (tmp_path / "secret.txt").write_text("secret")
    settings.web_dir = root / "current"

    response = TestClient(create_app(settings)).get("/../../secret.txt")

    assert response.status_code == 404
