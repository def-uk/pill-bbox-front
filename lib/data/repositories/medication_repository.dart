import 'package:sqflite/sqflite.dart';

import '../models/medication.dart';
import '../services/database_service.dart';

class MedicationRepository {
  MedicationRepository(this._db);

  final DatabaseService _db;

  Future<List<Medication>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('medications', orderBy: 'name');
    return rows.map(Medication.fromMap).toList();
  }

  /// 탐지된 약에 해당하는 약을 찾고, 없으면 1회 1정으로 등록한다.
  // TODO(개발 순서 2): 약 관리 화면이 생기면 등록된 약에만 기록하도록 바꾼다.
  Future<Medication> findOrCreateByCategory({
    required int categoryId,
    required String name,
  }) async {
    final db = await _db.database;
    await db.insert('medications', {
      'category_id': categoryId,
      'name': name,
      'dose_per_take': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query(
      'medications',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return Medication.fromMap(rows.single);
  }
}
