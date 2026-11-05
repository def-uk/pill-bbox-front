import 'package:flutter/foundation.dart';

import '../../utils/time_format.dart';
import '../models/medication.dart';
import '../models/prescription.dart';
import '../services/database_service.dart';
import 'medication_repository.dart';

/// 처방과 처방 속 약. 바뀌면 리스너에게 알린다.
class PrescriptionRepository extends ChangeNotifier {
  PrescriptionRepository(
    this._db,
    this._medications, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DatabaseService _db;
  final MedicationRepository _medications;
  final DateTime Function() _now;

  /// 등록한 처방 전부. 먼저 등록한 것부터.
  Future<List<Prescription>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('prescriptions', orderBy: 'created_at, id');
    final itemRows = await db.query('prescription_items', orderBy: 'id');
    final items = <int, List<PrescriptionItem>>{};
    for (final row in itemRows) {
      items
          .putIfAbsent(row['prescription_id']! as int, () => [])
          .add(
            PrescriptionItem(
              medicationId: row['medication_id']! as int,
              dosePerTake: row['dose_per_take']! as int,
              times: PrescriptionItem.decodeTimes(row['times']! as String),
            ),
          );
    }
    return [
      for (final row in rows)
        Prescription(
          id: row['id']! as int,
          startDate: parseDateKey(row['start_date']! as String)!,
          days: row['days']! as int,
          status:
              PrescriptionStatus.fromName(row['status']) ??
              PrescriptionStatus.active,
          items: items[row['id']] ?? const [],
        ),
    ];
  }

  Future<Prescription?> getById(int id) async =>
      (await getAll()).where((p) => p.id == id).firstOrNull;

  /// [day]의 일정에 회차가 들어가는 처방. 먼저 등록한 것부터.
  Future<List<Prescription>> scheduledOn(DateTime day) async => [
    for (final p in await getAll())
      if (p.isScheduledOn(day)) p,
  ];

  /// 처방을 등록하거나([id]가 null) 고친다. 처방 속 약은 통째로 바꾸고, 그 약들은 처방약이 된다.
  /// 처방 id를 돌려준다.
  ///
  /// [status]는 가져오기에서만 넘긴다. 고칠 때는 그대로 둔다.
  Future<int> save({
    int? id,
    required DateTime startDate,
    required int days,
    required List<PrescriptionItem> items,
    PrescriptionStatus? status,
  }) async {
    if (days < 1) throw ArgumentError.value(days, 'days');
    if (items.isEmpty) throw ArgumentError.value(items, 'items');
    final db = await _db.database;
    final values = {
      'start_date': dateKey(startDate),
      'days': days,
      'status': ?status?.name,
    };
    final savedId = await db.transaction((txn) async {
      final prescriptionId =
          id ??
          await txn.insert('prescriptions', {
            ...values,
            'created_at': _now().millisecondsSinceEpoch,
          });
      if (id != null) {
        await txn.update(
          'prescriptions',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'prescription_items',
          where: 'prescription_id = ?',
          whereArgs: [id],
        );
      }
      for (final item in items) {
        await txn.insert('prescription_items', {
          'prescription_id': prescriptionId,
          'medication_id': item.medicationId,
          'dose_per_take': item.dosePerTake,
          'times': PrescriptionItem.encodeTimes(item.times),
        });
      }
      return prescriptionId;
    });
    await _medications.setKind({
      for (final item in items) item.medicationId,
    }, MedicationKind.prescription);
    notifyListeners();
    return savedId;
  }

  /// 처방을 지운다. 약과 복용 기록은 그대로 둔다.
  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('prescriptions', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }
}
