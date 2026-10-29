import 'package:flutter/foundation.dart';

import '../../data/models/medication.dart';
import '../../data/repositories/medication_repository.dart';

class MedicationListViewModel extends ChangeNotifier {
  MedicationListViewModel({required this._medications}) {
    _medications.addListener(load);
  }

  final MedicationRepository _medications;
  bool _disposed = false;

  bool loading = true;
  List<Medication> medications = const [];

  Future<void> load() async {
    final medications = await _medications.getAll();
    if (_disposed) return;
    this.medications = medications;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _medications.removeListener(load);
    super.dispose();
  }
}
