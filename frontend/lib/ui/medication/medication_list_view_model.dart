import 'package:flutter/foundation.dart';

import '../../data/models/medication.dart';
import '../../data/models/prescription.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/prescription_repository.dart';

class MedicationListViewModel extends ChangeNotifier {
  MedicationListViewModel({
    required this._medications,
    required this._prescriptions,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _medications.addListener(load);
    _prescriptions.addListener(load);
  }

  final MedicationRepository _medications;
  final PrescriptionRepository _prescriptions;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  List<Medication> medications = const [];

  /// 최근 등록한 처방부터.
  List<Prescription> prescriptions = const [];

  DateTime get today => _now();

  String nameOf(int medicationId) =>
      medications.where((m) => m.id == medicationId).firstOrNull?.name ??
      '알 수 없는 약';

  Future<void> load() async {
    final medications = await _medications.getAll();
    final prescriptions = await _prescriptions.getAll();
    if (_disposed) return;
    this.medications = medications;
    this.prescriptions = prescriptions.reversed.toList();
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _medications.removeListener(load);
    _prescriptions.removeListener(load);
    super.dispose();
  }
}
