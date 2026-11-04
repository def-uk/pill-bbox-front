import 'package:flutter/foundation.dart';

import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required this._intakes, required this._medications}) {
    _intakes.addListener(load);
    _medications.addListener(load);
  }

  final IntakeRepository _intakes;
  final MedicationRepository _medications;
  bool _disposed = false;

  bool loading = true;

  /// 기록이 있는 날짜. 최근 날짜부터.
  List<DateTime> days = const [];

  Future<void> load() async {
    final days = await _intakes.recordedDays();
    if (_disposed) return;
    this.days = days;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _intakes.removeListener(load);
    _medications.removeListener(load);
    super.dispose();
  }
}
