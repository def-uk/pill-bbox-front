import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../utils/time_format.dart';
import '../models/medication.dart';
import '../services/database_service.dart';
import '../services/photo_storage_service.dart';
import 'intake_repository.dart';

/// 약과 복용 일정. 바뀌면 리스너에게 알린다.
class MedicationRepository extends ChangeNotifier {
  MedicationRepository(this._db, this._photos);

  final DatabaseService _db;
  final PhotoStorageService _photos;

  /// 등록한 약 전부. 이름순.
  Future<List<Medication>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('medications', orderBy: 'name, id');
    final times = await _timesByMedication(db);
    return [
      for (final row in rows)
        Medication.fromMap(row, times: times[row['id']] ?? const []),
    ];
  }

  Future<Medication?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final times = await _timesByMedication(db, medicationId: id);
    return Medication.fromMap(rows.single, times: times[id] ?? const []);
  }

  /// 약을 등록하거나([id]가 null) 고친다. 복용 시간은 통째로 바꾼다. 약 id를 돌려준다.
  Future<int> save({
    int? id,
    required int? categoryId,
    required String name,
    required int dosePerTake,
    required List<int> times,
  }) async {
    final db = await _db.database;
    final values = {
      'category_id': categoryId,
      'name': name,
      'dose_per_take': dosePerTake,
    };
    final savedId = await db.transaction((txn) async {
      final medicationId = id ?? await txn.insert('medications', values);
      if (id != null) {
        await txn.update(
          'medications',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'schedules',
          where: 'medication_id = ?',
          whereArgs: [id],
        );
      }
      for (final time in {...times}) {
        await txn.insert('schedules', {
          'medication_id': medicationId,
          'time': formatMinuteOfDay(time),
        });
      }
      return medicationId;
    });
    notifyListeners();
    return savedId;
  }

  /// 약을 지운다. 일정과 복용 기록도 함께 지워지고, 더 쓰이지 않는 사진도 지운다.
  Future<void> delete(int id) async {
    final db = await _db.database;
    final unused = await db.transaction((txn) async {
      final rows = await txn.query(
        'intake_records',
        columns: ['photo_path'],
        where: 'medication_id = ? AND photo_path IS NOT NULL',
        whereArgs: [id],
      );
      await txn.delete('medications', where: 'id = ?', whereArgs: [id]);
      return unusedPhotoPaths(txn, {
        for (final r in rows) r['photo_path']! as String,
      });
    });
    for (final path in unused) {
      await _photos.delete(path);
    }
    notifyListeners();
  }

  static Future<Map<int, List<int>>> _timesByMedication(
    DatabaseExecutor db, {
    int? medicationId,
  }) async {
    final rows = await db.query(
      'schedules',
      where: medicationId == null ? null : 'medication_id = ?',
      whereArgs: medicationId == null ? null : [medicationId],
      orderBy: 'time',
    );
    final times = <int, List<int>>{};
    for (final row in rows) {
      times
          .putIfAbsent(row['medication_id']! as int, () => [])
          .add(parseMinuteOfDay(row['time']! as String));
    }
    return times;
  }
}
