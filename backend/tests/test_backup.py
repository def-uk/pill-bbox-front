def snapshot(**overrides) -> dict:
    return {
        "schema": 1,
        "exported_at": "2026-11-04T21:30:00+09:00",
        "medications": [
            {"name": "타이레놀정500mg", "category_id": 250, "dose_per_take": 1, "times": ["08:00"]}
        ],
        "records": [
            {
                "taken_at": "2026-11-04T08:05:12+09:00",
                "medication": "타이레놀정500mg",
                "count": 1,
                "source": "camera",
            }
        ],
        "appearances": [
            {"medication": "타이레놀정500mg", "l": 82.1, "a": -1.3, "b": 6.4, "elongation": 2.31}
        ],
    } | overrides


def put(client, auth, revision, body=None):
    return client.put(
        "/v1/backup", headers=auth | {"If-Match": f'"{revision}"'}, json=body or snapshot()
    )


def test_first_backup_then_get(client, auth):
    assert client.get("/v1/backup", headers=auth).status_code == 404

    saved = put(client, auth, 0)
    assert saved.status_code == 200
    assert saved.json()["revision"] == 1
    assert saved.headers["ETag"] == '"1"'

    got = client.get("/v1/backup", headers=auth)
    assert got.headers["ETag"] == '"1"'
    assert got.json()["revision"] == 1
    assert got.json()["data"] == snapshot()


def test_put_without_if_match_is_428(client, auth):
    assert client.put("/v1/backup", headers=auth, json=snapshot()).status_code == 428


def test_stale_revision_is_412(client, auth):
    put(client, auth, 0)
    put(client, auth, 1)

    stale = put(client, auth, 1)

    assert stale.status_code == 412
    assert "리비전 2" in stale.json()["detail"]


def test_keeps_only_recent_revisions(client, auth, settings):
    from sqlalchemy import select

    from app.models import Backup

    for revision in range(12):
        assert put(client, auth, revision).status_code == 200

    with client.app.state.sessions() as session:
        kept = session.scalars(select(Backup.revision).order_by(Backup.revision)).all()
    assert kept == list(range(3, 13))
    assert len(kept) == settings.backup_revisions_kept


def test_record_of_unknown_medication_is_422(client, auth):
    body = snapshot(medications=[])

    response = put(client, auth, 0, body)

    assert response.status_code == 422
    assert "타이레놀정500mg" in response.text


def test_bad_time_and_naive_datetime_are_422(client, auth):
    medication = snapshot()["medications"][0] | {"times": ["8:00"]}
    assert put(client, auth, 0, snapshot(medications=[medication])).status_code == 422

    record = snapshot()["records"][0] | {"taken_at": "2026-11-04T08:05:12"}
    assert put(client, auth, 0, snapshot(records=[record])).status_code == 422


def test_vaults_do_not_see_each_other(client, auth):
    put(client, auth, 0)
    other = {"Authorization": f"Bearer {client.post('/v1/vaults').json()['code']}"}

    assert client.get("/v1/backup", headers=other).status_code == 404
