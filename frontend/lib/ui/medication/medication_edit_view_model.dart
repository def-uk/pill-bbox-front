import 'package:flutter/foundation.dart';

import '../../data/models/drug_info.dart';
import '../../data/models/pill_label.dart';
import '../../data/repositories/drug_info_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/drug_info_service.dart';
import '../../data/services/pill_label_service.dart';

/// 약 등록·수정. [medicationId]가 null이면 새로 등록한다.
class MedicationEditViewModel extends ChangeNotifier {
  MedicationEditViewModel({
    required this._medications,
    required this._labels,
    required this._drugs,
    this.medicationId,
  });

  final MedicationRepository _medications;
  final PillLabelService _labels;
  final DrugInfoRepository _drugs;
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

  /// 이번에 식약처에서 고른 약. 저장할 때 약 정보를 이어 둔다.
  DrugSummary? pickedDrug;

  /// 이미 이어 둔 식약처 약 정보가 있다.
  bool hasDrugInfo = false;

  /// 약을 바꿨다. 저장할 때 예전 약 정보를 떼거나 새로 잇는다.
  bool _drugChanged = false;

  /// 식약처에서 찾을 수 있다 (API_BASE_URL을 넣은 빌드).
  bool get canSearchDrugs => _drugs.available;

  /// 식약처 의약품에서 고른 약.
  bool get fromMfds =>
      pickedDrug != null ||
      (!_drugChanged && hasDrugInfo && categoryId == null);

  /// 약 정보 화면을 열 수 있다. 서버가 없어도 받아 둔 정보는 보인다.
  bool get canOpenDrugInfo =>
      !isNew && !_drugChanged && (_drugs.available || hasDrugInfo);

  Future<DrugPage> searchDrugs(String query) => _drugs.search(query);

  String drugImageUrl(String itemSeq) => _drugs.imageUrl(itemSeq);

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
    final info = current == null ? null : await _drugs.cached(current.id);
    if (_disposed) return;
    hasDrugInfo = info != null;
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
    _pick(null);
  }

  /// 식약처 의약품에서 고른 약. 모델이 모르는 약이라 사진으로 인식되지 않는다.
  void selectDrug(DrugSummary drug) {
    categoryId = null;
    name = drug.name;
    _pick(drug);
  }

  /// 모델이 모르는 약. 사진으로 인식되지 않아 직접 기록만 할 수 있다.
  void setCustomName(String value) {
    categoryId = null;
    name = value.trim();
    _pick(null);
  }

  void _pick(DrugSummary? drug) {
    pickedDrug = drug;
    _drugChanged = true;
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
    final id = await _medications.save(
      id: medicationId,
      categoryId: categoryId,
      name: name.trim(),
      dosePerTake: dosePerTake,
      times: times,
    );
    if (_drugChanged) {
      final drug = pickedDrug;
      if (drug == null) {
        await _drugs.unlink(id);
      } else {
        try {
          await _drugs.link(id, drug.itemSeq);
        } on DrugInfoException {
          // 약은 저장됐다. 약 정보 화면에서 다시 고르면 된다.
        }
      }
    }
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
