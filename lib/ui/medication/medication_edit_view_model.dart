import 'package:flutter/foundation.dart';

import '../../data/models/pill_label.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/pill_label_service.dart';

/// 약 등록·수정. [medicationId]가 null이면 새로 등록한다.
class MedicationEditViewModel extends ChangeNotifier {
  MedicationEditViewModel({
    required this._medications,
    required this._labels,
    this.medicationId,
  });

  final MedicationRepository _medications;
  final PillLabelService _labels;
  final int? medicationId;
  bool _disposed = false;

  bool loading = true;
  bool saving = false;
  bool notFound = false;

  /// 고를 수 있는 약: 모델이 아는 약 중 다른 약으로 등록하지 않은 것.
  List<PillLabel> availableLabels = const [];

  /// 모델이 아는 약이면 category_id, 직접 입력한 약이면 null.
  int? categoryId;
  String name = '';
  int dosePerTake = 1;
  List<int> times = const [];

  bool get isNew => medicationId == null;
  bool get canSave => !loading && !saving && name.trim().isNotEmpty;

  /// 시간 추가 화면의 처음 값: 마지막 시간 4시간 뒤, 없으면 08:00.
  int get suggestedTime =>
      times.isEmpty ? 8 * 60 : (times.last + 4 * 60) % (24 * 60);

  Future<void> load() async {
    final labels = await _labels.load();
    final medications = await _medications.getAll();
    final usedByOthers = {
      for (final m in medications)
        if (m.id != medicationId && m.categoryId != null) m.categoryId,
    };
    final current = medications.where((m) => m.id == medicationId).firstOrNull;
    if (_disposed) return;
    availableLabels = [
      for (final l in labels)
        if (!usedByOthers.contains(l.categoryId)) l,
    ];
    if (medicationId != null && current == null) notFound = true;
    if (current != null) {
      categoryId = current.categoryId;
      name = current.name;
      dosePerTake = current.dosePerTake;
      times = current.times;
    }
    loading = false;
    notifyListeners();
  }

  void selectLabel(PillLabel label) {
    categoryId = label.categoryId;
    name = label.name;
    notifyListeners();
  }

  /// 모델이 모르는 약. 사진으로 인식되지 않아 직접 기록만 할 수 있다.
  void setCustomName(String value) {
    categoryId = null;
    name = value.trim();
    notifyListeners();
  }

  void setDose(int value) {
    if (value < 1) return;
    dosePerTake = value;
    notifyListeners();
  }

  void addTime(int minute) {
    if (times.contains(minute)) return;
    times = [...times, minute]..sort();
    notifyListeners();
  }

  void removeTime(int minute) {
    times = [...times]..remove(minute);
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canSave) return false;
    saving = true;
    notifyListeners();
    await _medications.save(
      id: medicationId,
      categoryId: categoryId,
      name: name.trim(),
      dosePerTake: dosePerTake,
      times: times,
    );
    return true;
  }

  Future<void> delete() async {
    saving = true;
    notifyListeners();
    await _medications.delete(medicationId!);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
