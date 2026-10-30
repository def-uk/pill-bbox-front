import 'package:flutter/foundation.dart';

import '../../data/models/medication.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../utils/intake_matcher.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._intakes,
    required this._medications,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _intakes.addListener(load);
    _medications.addListener(load);
  }

  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  DateTime today = DateTime.now();
  List<Medication> medications = const [];
  DaySummary summary = const DaySummary(slots: [], unscheduled: []);

  /// 시간대별 일정. 시간순.
  List<(int, List<DoseSlot>)> get slotsByTime {
    final groups = <int, List<DoseSlot>>{};
    for (final slot in summary.slots) {
      groups.putIfAbsent(slot.time, () => []).add(slot);
    }
    return [for (final e in groups.entries) (e.key, e.value)];
  }

  String nameOf(int medicationId) =>
      medications.where((m) => m.id == medicationId).firstOrNull?.name ??
      '알 수 없는 약';

  Future<void> load() async {
    final now = _now();
    final medications = await _medications.getAll();
    final records = await _intakes.recordsOn(now);
    if (_disposed) return;
    today = now;
    this.medications = medications;
    summary = summarizeDay(medications, records);
    loading = false;
    notifyListeners();
  }

  /// 남은 개수만큼 직접 복용 기록을 남긴다.
  Future<void> markTaken(DoseSlot slot) => _intakes.addManualIntake(
    medicationId: slot.medication.id,
    count: slot.remaining,
  );

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    _medications.removeListener(load);
    super.dispose();
  }
}
