import 'package:flutter/foundation.dart';

import '../../data/models/intake_record.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';

class TodayIntake {
  const TodayIntake({
    required this.name,
    required this.count,
    required this.takenAt,
    required this.source,
  });

  final String name;
  final int count;
  final DateTime takenAt;
  final IntakeSource source;
}

// TODO(개발 순서 2): 일정과 비교해 예정·완료를 보여 준다.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._intakes,
    required this._medications,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _intakes.addListener(load);
  }

  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  List<TodayIntake> intakes = const [];

  Future<void> load() async {
    final records = await _intakes.recordsOn(_now());
    final names = {for (final m in await _medications.getAll()) m.id: m.name};
    if (_disposed) return;
    intakes = [
      for (final r in records)
        TodayIntake(
          name: names[r.medicationId] ?? '알 수 없는 약',
          count: r.count,
          takenAt: r.takenAt,
          source: r.source,
        ),
    ];
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    super.dispose();
  }
}
