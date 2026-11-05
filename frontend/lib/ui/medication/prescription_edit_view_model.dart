import 'package:flutter/foundation.dart';

import '../../data/models/drug_info.dart';
import '../../data/models/medication.dart';
import '../../data/models/pill_label.dart';
import '../../data/models/prescription.dart';
import '../../data/repositories/drug_info_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../data/services/drug_info_service.dart';
import '../../data/services/pill_label_service.dart';
import '../common/drug_search_sheet.dart';

/// 처방 등록 화면의 약 한 줄. 아직 등록하지 않은 약이면 저장할 때 처방약으로 등록한다.
class PrescriptionItemDraft {
  const PrescriptionItemDraft({
    this.medication,
    this.categoryId,
    this.drug,
    required this.name,
    required this.dosePerTake,
    required this.times,
  });

  /// 등록한 약. 아직 등록하지 않은 약이면 null.
  final Medication? medication;

  /// 등록하지 않은 약 중 모델이 아는 약의 category_id.
  final int? categoryId;

  /// 등록하지 않은 약 중 식약처에서 고른 약. 저장할 때 약 정보를 이어 둔다.
  final DrugSummary? drug;
  final String name;

  /// 1회 알 수.
  final int dosePerTake;

  /// 회차 시간. 자정부터 센 분, 오름차순.
  final List<int> times;

  PrescriptionItemDraft copyWith({int? dosePerTake, List<int>? times}) =>
      PrescriptionItemDraft(
        medication: medication,
        categoryId: categoryId,
        drug: drug,
        name: name,
        dosePerTake: dosePerTake ?? this.dosePerTake,
        times: times ?? this.times,
      );

  bool isSameMedication(PrescriptionItemDraft other) =>
      medication != null && other.medication != null
      ? medication!.id == other.medication!.id
      : medication == null && other.medication == null && name == other.name;
}

/// 처방 등록·수정 (docs/MVP.md 4.2). [prescriptionId]가 null이면 새로 등록한다.
class PrescriptionEditViewModel extends ChangeNotifier {
  PrescriptionEditViewModel({
    required this._prescriptions,
    required this._medications,
    required this._labels,
    required this._drugs,
    this.prescriptionId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final today = _now();
    startDate = DateTime(today.year, today.month, today.day);
  }

  final PrescriptionRepository _prescriptions;
  final MedicationRepository _medications;
  final PillLabelService _labels;
  final DrugInfoRepository _drugs;
  final int? prescriptionId;
  final DateTime Function() _now;
  bool _disposed = false;

  bool loading = true;
  bool saving = false;
  bool notFound = false;

  /// 등록한 약 전부.
  List<Medication> medications = const [];

  /// 모델이 아는 약 중 아직 등록하지 않은 것.
  List<PillLabel> availableLabels = const [];

  late DateTime startDate;
  int days = 7;
  List<PrescriptionItemDraft> items = const [];

  /// 처방 일수 빠른 선택.
  static const quickDays = [3, 5, 7, 14, 28, 30];

  bool get isNew => prescriptionId == null;
  bool get canSave =>
      !loading &&
      !saving &&
      items.isNotEmpty &&
      items.every((i) => i.times.isNotEmpty);

  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + days - 1);

  DateTime get today {
    final t = _now();
    return DateTime(t.year, t.month, t.day);
  }

  bool get canSearchDrugs => _drugs.available;
  Future<DrugPage> searchDrugs(String query) => _drugs.search(query);
  String drugImageUrl(String itemSeq) => _drugs.imageUrl(itemSeq);

  /// 아직 처방에 넣지 않은 등록한 약.
  List<Medication> get pickableMedications => [
    for (final m in medications)
      if (!items.any((i) => i.medication?.id == m.id)) m,
  ];

  Future<void> load() async {
    final labels = await _labels.load();
    final medications = await _medications.getAll();
    final current = prescriptionId == null
        ? null
        : await _prescriptions.getById(prescriptionId!);
    if (_disposed) return;
    this.medications = medications;
    final registered = {for (final m in medications) m.categoryId};
    availableLabels = [
      for (final l in labels)
        if (!registered.contains(l.categoryId)) l,
    ];
    if (prescriptionId != null && current == null) notFound = true;
    if (current != null) {
      final byId = {for (final m in medications) m.id: m};
      startDate = current.startDate;
      days = current.days;
      items = [
        for (final item in current.items)
          if (byId[item.medicationId] case final m?)
            PrescriptionItemDraft(
              medication: m,
              name: m.name,
              dosePerTake: item.dosePerTake,
              times: item.times,
            ),
      ];
    }
    loading = false;
    notifyListeners();
  }

  /// 약 고르기 시트에서 고른 것([DrugSearchSheet])으로 줄을 만든다. 이미 등록한 약이면 그 약을 쓴다.
  /// 회차 시간은 바로 앞 줄과 같게, 처음이면 그 약의 복용 시간으로 둔다.
  PrescriptionItemDraft draftFor(Object picked) {
    Medication? registered(bool Function(Medication) test) =>
        medications.where(test).firstOrNull;
    final medication = switch (picked) {
      Medication m => m,
      PillLabel l => registered((m) => m.categoryId == l.categoryId),
      DrugSummary d => registered((m) => m.name == d.name),
      CustomDrugName(:final name) => registered((m) => m.name == name.trim()),
      _ => throw ArgumentError.value(picked, 'picked'),
    };
    final times = items.isNotEmpty
        ? items.last.times
        : medication?.times ?? const <int>[];
    if (medication != null) {
      return PrescriptionItemDraft(
        medication: medication,
        name: medication.name,
        dosePerTake: medication.dosePerTake,
        times: times,
      );
    }
    return switch (picked) {
      PillLabel l => PrescriptionItemDraft(
        categoryId: l.categoryId,
        name: l.name,
        dosePerTake: 1,
        times: times,
      ),
      DrugSummary d => PrescriptionItemDraft(
        drug: d,
        name: d.name,
        dosePerTake: 1,
        times: times,
      ),
      CustomDrugName(:final name) => PrescriptionItemDraft(
        name: name.trim(),
        dosePerTake: 1,
        times: times,
      ),
      _ => throw ArgumentError.value(picked, 'picked'),
    };
  }

  /// [index] 줄을 바꾸거나, null이면 더한다. 같은 약이 이미 있으면 그 줄을 바꾼다.
  void putItem(int? index, PrescriptionItemDraft item) {
    final at = index ?? items.indexWhere(item.isSameMedication);
    items = [...items];
    if (at < 0) {
      items.add(item);
    } else {
      items[at] = item;
    }
    notifyListeners();
  }

  void removeItem(int index) {
    items = [...items]..removeAt(index);
    notifyListeners();
  }

  void setStartDate(DateTime value) {
    startDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  void setDays(int value) {
    if (value < 1) return;
    days = value;
    notifyListeners();
  }

  /// 아직 등록하지 않은 약을 처방약으로 등록하고 처방을 저장한다. 저장했으면 true.
  Future<bool> save() async {
    if (!canSave) return false;
    saving = true;
    notifyListeners();
    final saved = <PrescriptionItem>[];
    for (final (i, item) in items.indexed) {
      var id = item.medication?.id;
      if (id == null) {
        id = await _medications.save(
          categoryId: item.categoryId,
          name: item.name,
          dosePerTake: item.dosePerTake,
          times: const [],
          kind: MedicationKind.prescription,
        );
        // 저장이 중간에 실패해 다시 눌러도 같은 약을 또 등록하지 않게 바로 바꿔 둔다.
        items = [...items]
          ..[i] = PrescriptionItemDraft(
            medication: await _medications.getById(id),
            name: item.name,
            dosePerTake: item.dosePerTake,
            times: item.times,
          );
        if (item.drug case final drug?) {
          try {
            await _drugs.link(id, drug.itemSeq);
          } on DrugInfoException {
            // 약은 저장됐다. 약 정보 화면에서 다시 고르면 된다.
          }
        }
      }
      saved.add(
        PrescriptionItem(
          medicationId: id,
          dosePerTake: item.dosePerTake,
          times: item.times,
        ),
      );
    }
    await _prescriptions.save(
      id: prescriptionId,
      startDate: startDate,
      days: days,
      items: saved,
    );
    return true;
  }

  Future<void> delete() async {
    saving = true;
    notifyListeners();
    await _prescriptions.delete(prescriptionId!);
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
