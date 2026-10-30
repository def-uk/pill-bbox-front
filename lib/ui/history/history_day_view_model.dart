import 'package:flutter/foundation.dart';

import '../../data/models/intake_record.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/photo_storage_service.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.record,
    required this.name,
    required this.photoFile,
  });

  final IntakeRecord record;
  final String name;

  /// 사진 파일의 절대 경로. 직접 기록이면 null.
  final String? photoFile;
}

/// 하루의 복용 기록.
class HistoryDayViewModel extends ChangeNotifier {
  HistoryDayViewModel({
    required this.day,
    required this._intakes,
    required this._medications,
    required this._photos,
  }) {
    _intakes.addListener(load);
    _medications.addListener(load);
  }

  final DateTime day;
  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  final PhotoStorageService _photos;
  bool _disposed = false;

  bool loading = true;
  List<HistoryEntry> entries = const [];

  Future<void> load() async {
    final records = await _intakes.recordsOn(day);
    final names = {for (final m in await _medications.getAll()) m.id: m.name};
    final entries = [
      for (final r in records)
        HistoryEntry(
          record: r,
          name: names[r.medicationId] ?? '알 수 없는 약',
          photoFile: r.photoPath == null
              ? null
              : await _photos.resolve(r.photoPath!),
        ),
    ];
    if (_disposed) return;
    this.entries = entries;
    loading = false;
    notifyListeners();
  }

  Future<void> delete(HistoryEntry entry) => _intakes.delete(entry.record.id);

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    _medications.removeListener(load);
    super.dispose();
  }
}
