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
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
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
          dose_per_take INTEGER NOT NULL DEFAULT 1
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
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await (await database)?.close();
  }
}
