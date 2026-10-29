import 'package:flutter/foundation.dart';

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
    final takenAt = _now().millisecondsSinceEpoch;
    try {
      final db = await _db.database;
      await db.transaction((txn) async {
        for (final e in counts.entries) {
          await txn.insert('intake_records', {
            'medication_id': e.key,
            'taken_at': takenAt,
            'count': e.value,
            'source': IntakeSource.camera.name,
            'photo_path': photoPath,
          });
        }
      });
    } catch (_) {
      await _photos.delete(photoPath);
      rethrow;
    }
    notifyListeners();
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
}
