import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 기기 안 SQLite. 테이블 구성은 docs/DESIGN.md 5.2를 따른다.
class DatabaseService {
  DatabaseService({DatabaseFactory? factory, this._path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    final path =
        _path ?? p.join(await _factory.getDatabasesPath(), 'pillbbox.db');
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE medications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER UNIQUE,
          name TEXT NOT NULL,
          dose_per_take INTEGER NOT NULL DEFAULT 1,
          kind TEXT,
          daily_limit INTEGER
        )''')
      ..execute('''
        CREATE TABLE schedules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
          time TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE intake_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
          taken_at INTEGER NOT NULL,
          count INTEGER NOT NULL,
          source TEXT NOT NULL,
          photo_path TEXT
        )''')
      ..execute(
        'CREATE INDEX idx_intake_records_taken_at ON intake_records(taken_at)',
      );
    _createAppearances(batch);
    _createDrugInfos(batch);
    _createPrescriptions(batch);
    _createMonsters(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _upgrade(Database db, int from, int to) async {
    final batch = db.batch();
    if (from < 2) _createAppearances(batch);
    if (from < 3) _createDrugInfos(batch);
    if (from < 4) {
      batch
        ..execute('ALTER TABLE medications ADD COLUMN kind TEXT')
        ..execute('ALTER TABLE medications ADD COLUMN daily_limit INTEGER');
      _createPrescriptions(batch);
    }
    if (from < 5) {
      if (from >= 4) {
        batch.execute('ALTER TABLE prescriptions ADD COLUMN ended_on TEXT');
      }
      _createMonsters(batch);
    }
    await batch.commit(noResult: true);
  }

  /// 버전 2. 사용자가 사진 속 물체에 고른 약의 색·모양 (비슷한 약 추천).
  static void _createAppearances(Batch batch) => batch.execute('''
    CREATE TABLE appearances (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
      l REAL NOT NULL,
      a REAL NOT NULL,
      b REAL NOT NULL,
      elongation REAL NOT NULL
    )''');

  /// 버전 3. 약마다 이어 둔 식약처 의약품 정보. 서버가 꺼져도 볼 수 있게 받은 그대로 둔다.
  /// 공공 정보를 다시 받으면 되므로 백업에는 넣지 않는다.
  static void _createDrugInfos(Batch batch) => batch.execute('''
    CREATE TABLE drug_infos (
      medication_id INTEGER PRIMARY KEY REFERENCES medications(id) ON DELETE CASCADE,
      item_seq TEXT NOT NULL,
      data TEXT NOT NULL,
      fetched_at INTEGER NOT NULL
    )''');

  /// 버전 4. 처방(병원에서 한 번에 받은 약 묶음)과 처방 속 약 (docs/MVP.md 4.3).
  /// 약 종류(medications.kind)와 영양제 하루 권장량(medications.daily_limit)도 이때 더했다.
  static void _createPrescriptions(Batch batch) => batch
    ..execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        days INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        ended_on TEXT
      )''')
    ..execute('''
      CREATE TABLE prescription_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prescription_id INTEGER NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
        medication_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        dose_per_take INTEGER NOT NULL,
        times TEXT NOT NULL
      )''');

  /// 버전 5. 처방 몬스터의 생김새(처방 속 약의 색·모양). 이름이 바뀌지 않게 처음 정한 것을 둔다.
  /// 체력과 경험치는 기록에서 다시 세므로 저장하지 않는다 (utils/reward_calculator.dart).
  /// 처방을 끝낸 날(prescriptions.ended_on)도 이때 더했다.
  static void _createMonsters(Batch batch) => batch.execute('''
    CREATE TABLE monsters (
      prescription_id INTEGER PRIMARY KEY REFERENCES prescriptions(id) ON DELETE CASCADE,
      color TEXT NOT NULL,
      shape TEXT NOT NULL
    )''');

  Future<void> close() async {
    final database = _database;
    _database = null;
    await (await database)?.close();
  }
}
