import 'package:flutter/foundation.dart';

import '../../data/models/detection.dart';
import '../../data/models/medication.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/pill_detector.dart';
import '../../utils/intake_matcher.dart';

/// 이 값보다 신뢰도가 낮으면 "확인 필요". 모델 저장소의 POINT_CONF와 같다.
const reviewConfidence = 0.5;

enum ResultStatus { detecting, ready, saving, failed }

/// 결과 화면의 한 줄: 약 한 종류의 예정 개수와 확인한 개수.
class ResultLine {
  const ResultLine({
    required this.medication,
    required this.categoryId,
    required this.name,
    required this.count,
    required this.expected,
    required this.needsReview,
  });

  /// 등록한 약. 등록하지 않은 약으로 인식했으면 null이고, 저장되지 않는다.
  final Medication? medication;
  final int? categoryId;
  final String name;
  final int count;

  /// 지금 먹어야 할 개수. 지금 예정에 없으면 0.
  final int expected;
  final bool needsReview;

  bool get isRegistered => medication != null;
  MatchStatus get status => matchStatus(expected: expected, recognized: count);
}

class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.photo,
    required this._detector,
    required this._medications,
    required this._intakes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Uint8List photo;
  final PillDetector _detector;
  final MedicationRepository _medications;
  final IntakeRepository _intakes;
  final DateTime Function() _now;
  bool _disposed = false;

  ResultStatus status = ResultStatus.detecting;
  String? errorMessage;
  List<Detection> detections = const [];

  /// 등록한 약 전부. 약 바꾸기·약 추가에서 고른다.
  List<Medication> medications = const [];

  Map<int, int> _due = {};
  final _counts = <int, int>{};
  final _review = <int>{};

  /// 등록한 약 줄의 순서. medication_id.
  final _order = <int>[];

  /// 등록하지 않은 약. category_id → 줄.
  final _unregistered = <int, ResultLine>{};

  List<ResultLine> get lines {
    final byId = {for (final m in medications) m.id: m};
    return [
      for (final id in _order)
        ResultLine(
          medication: byId[id],
          categoryId: byId[id]!.categoryId,
          name: byId[id]!.name,
          count: _counts[id] ?? 0,
          expected: _due[id] ?? 0,
          needsReview: _review.contains(id),
        ),
      ..._unregistered.values,
    ];
  }

  bool get hasUnregistered => _unregistered.values.any((l) => l.count > 0);
  bool get canSave =>
      status == ResultStatus.ready && _counts.values.any((c) => c > 0);

  Future<void> detect() async {
    try {
      final now = _now();
      medications = await _medications.getAll();
      final records = await _intakes.recordsOn(now);
      _due = dueNow(summarizeDay(medications, records), now);

      await _detector.load();
      detections = await _detector.detect(photo);
      _arrange(detections);
      status = ResultStatus.ready;
    } catch (e) {
      errorMessage = '알약을 찾지 못했습니다';
      status = ResultStatus.failed;
    }
    _notify();
  }

  void increment(ResultLine line) => _setCount(line, line.count + 1);

  void decrement(ResultLine line) {
    if (line.count > 0) _setCount(line, line.count - 1);
  }

  /// [line]의 개수를 [medication]으로 옮긴다. 모델이 다른 약으로 인식했을 때 쓴다.
  void changeMedication(ResultLine line, Medication medication) {
    if (line.medication?.id == medication.id) return;
    if (line.medication case final from?) {
      _counts.remove(from.id);
      _review.remove(from.id);
      if (!_due.containsKey(from.id)) _order.remove(from.id);
    } else {
      _unregistered.remove(line.categoryId);
    }
    _addCount(medication, line.count);
    _notify();
  }

  /// 모델이 못 찾은 약을 1정 더한다.
  void addMedication(Medication medication) {
    _addCount(medication, 1);
    _notify();
  }

  /// 확인한 개수로 복용 기록을 저장한다. 저장했으면 true.
  Future<bool> save() async {
    if (!canSave) return false;
    status = ResultStatus.saving;
    _notify();
    try {
      await _intakes.addCameraIntake(photo: photo, countsByMedication: _counts);
      return true;
    } catch (e) {
      status = ResultStatus.ready;
      errorMessage = '저장하지 못했습니다';
      _notify();
      return false;
    }
  }

  /// 탐지 결과를 약별로 묶고, 지금 예정인데 못 찾은 약도 0정으로 넣는다.
  void _arrange(List<Detection> detections) {
    final byCategory = {
      for (final m in medications)
        if (m.categoryId != null) m.categoryId!: m,
    };
    final groups = <int, List<Detection>>{};
    for (final d in detections) {
      groups.putIfAbsent(d.categoryId, () => []).add(d);
    }
    for (final group in groups.values) {
      final needsReview = group.any((d) => d.confidence < reviewConfidence);
      final medication = byCategory[group.first.categoryId];
      if (medication == null) {
        _unregistered[group.first.categoryId] = ResultLine(
          medication: null,
          categoryId: group.first.categoryId,
          name: group.first.name,
          count: group.length,
          expected: 0,
          needsReview: needsReview,
        );
        continue;
      }
      _order.add(medication.id);
      _counts[medication.id] = group.length;
      if (needsReview) _review.add(medication.id);
    }
    for (final id in _due.keys) {
      if (!_order.contains(id)) _order.add(id);
    }
  }

  void _addCount(Medication medication, int count) {
    _counts[medication.id] = (_counts[medication.id] ?? 0) + count;
    if (!_order.contains(medication.id)) _order.add(medication.id);
  }

  void _setCount(ResultLine line, int count) {
    if (line.medication case final medication?) {
      _counts[medication.id] = count;
    } else {
      _unregistered[line.categoryId!] = ResultLine(
        medication: null,
        categoryId: line.categoryId,
        name: line.name,
        count: count,
        expected: 0,
        needsReview: line.needsReview,
      );
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
