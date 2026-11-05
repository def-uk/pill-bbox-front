import 'package:flutter/foundation.dart';

import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../utils/metrics.dart';

/// 4주 검증 지표 화면 (docs/MVP.md 9.2).
class MetricsViewModel extends ChangeNotifier {
  MetricsViewModel({
    required this._medications,
    required this._prescriptions,
    required this._intakes,
    required this._rewards,
    required this._settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationRepository _medications;
  final PrescriptionRepository _prescriptions;
  final IntakeRepository _intakes;
  final RewardRepository _rewards;
  final SettingsRepository _settings;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  TesterMetrics? metrics;

  Future<void> load() async {
    final metrics = computeMetrics(
      medications: await _medications.getAll(),
      prescriptions: await _prescriptions.getAll(),
      records: await _intakes.allRecords(),
      rewards: await _rewards.current(),
      today: _now(),
      shareSaves: await _settings.shareSaves(),
    );
    if (_disposed) return;
    this.metrics = metrics;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
