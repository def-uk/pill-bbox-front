import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'photo_storage_service.dart';

/// 복용 사진을 SQLite에 둔다. 파일을 쓸 수 없는 웹에서 쓰고, 브라우저 IndexedDB에 저장된다.
///
/// 기록 DB(DatabaseService)와 따로 두어 기록 테이블 구성(docs/DESIGN.md 5.2)은 기기와 같게 둔다.
class DbPhotoStorageService implements PhotoStorageService {
  DbPhotoStorageService({
    required this._factory,
    this._path = 'pillbbox_photos.db',
  });

  final DatabaseFactory _factory;
  final String _path;
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _factory.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE photos (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
      ),
    ),
  );

  @override
  Future<String> save(Uint8List bytes) async {
    final relativePath = newPhotoPath();
    await (await _db).insert('photos', {'path': relativePath, 'bytes': bytes});
    return relativePath;
  }

  @override
  Future<Uint8List?> load(String relativePath) async {
    final rows = await (await _db).query(
      'photos',
      columns: ['bytes'],
      where: 'path = ?',
      whereArgs: [relativePath],
    );
    return rows.isEmpty ? null : rows.first['bytes'] as Uint8List;
  }

  @override
  Future<void> delete(String relativePath) async {
    await (await _db).delete(
      'photos',
      where: 'path = ?',
      whereArgs: [relativePath],
    );
  }
}
