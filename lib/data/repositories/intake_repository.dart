import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/intake_record.dart';
import '../services/database_service.dart';
import '../services/photo_storage_service.dart';

/// 복용 기록. 기록이 바뀌면 리스너에게 알린다.
class IntakeRepository extends ChangeNotifier {
  IntakeRepository(this._db, this._photos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DatabaseService _db;
  final PhotoStorageService _photos;
  final DateTime Function() _now;

  /// 사진 한 장으로 확인한 약들을 같은 시각의 기록으로 저장한다.
  ///
  /// [countsByMedication]은 medication_id → 개수. 0개인 약은 건너뛴다.
  Future<void> addCameraIntake({
    required Uint8List photo,
    required Map<int, int> countsByMedication,
  }) async {
    final counts = {
      for (final e in countsByMedication.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (counts.isEmpty) return;

    final photoPath = await _photos.save(photo);
    try {
      await _insert(counts, IntakeSource.camera, photoPath);
    } catch (_) {
      await _photos.delete(photoPath);
      rethrow;
    }
    notifyListeners();
  }

  /// 사진 없이 직접 기록한다.
  Future<void> addManualIntake({
    required int medicationId,
    required int count,
  }) async {
    if (count <= 0) return;
    await _insert({medicationId: count}, IntakeSource.manual, null);
    notifyListeners();
  }

  Future<void> _insert(
    Map<int, int> counts,
    IntakeSource source,
    String? photoPath,
  ) async {
    final takenAt = _now().millisecondsSinceEpoch;
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final e in counts.entries) {
        await txn.insert('intake_records', {
          'medication_id': e.key,
          'taken_at': takenAt,
          'count': e.value,
          'source': source.name,
          'photo_path': photoPath,
        });
      }
    });
  }

  /// [day]가 속한 날(기기 시간대)의 기록. 시간순.
  Future<List<IntakeRecord>> recordsOn(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final db = await _db.database;
    final rows = await db.query(
      'intake_records',
      where: 'taken_at >= ? AND taken_at < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'taken_at, id',
    );
    return rows.map(IntakeRecord.fromMap).toList();
  }

  /// 기록이 있는 날짜(기기 시간대). 최근 날짜부터.
  Future<List<DateTime>> recordedDays() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT date(taken_at / 1000, 'unixepoch', 'localtime') AS day "
      'FROM intake_records ORDER BY day DESC',
    );
    return [for (final row in rows) DateTime.parse(row['day']! as String)];
  }

  /// 기록 하나를 지운다. 다른 기록이 쓰지 않는 사진이면 사진도 지운다.
  Future<void> delete(int recordId) async {
    final db = await _db.database;
    final unused = await db.transaction((txn) async {
      final rows = await txn.query(
        'intake_records',
        columns: ['photo_path'],
        where: 'id = ?',
        whereArgs: [recordId],
      );
      await txn.delete(
        'intake_records',
        where: 'id = ?',
        whereArgs: [recordId],
      );
      return unusedPhotoPaths(txn, {
        for (final r in rows)
          if (r['photo_path'] case final String path) path,
      });
    });
    for (final path in unused) {
      await _photos.delete(path);
    }
    notifyListeners();
  }
}

/// [paths] 중 어떤 복용 기록도 쓰지 않는 사진 경로.
Future<Set<String>> unusedPhotoPaths(
  DatabaseExecutor db,
  Set<String> paths,
) async {
  if (paths.isEmpty) return {};
  final rows = await db.query(
    'intake_records',
    columns: ['photo_path'],
    where: 'photo_path IN (${List.filled(paths.length, '?').join(', ')})',
    whereArgs: paths.toList(),
  );
  return paths.difference({for (final r in rows) r['photo_path']! as String});
}
