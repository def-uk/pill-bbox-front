import 'package:flutter/foundation.dart';

import '../../data/models/detection.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/pill_detector.dart';

/// 이 값보다 신뢰도가 낮으면 "확인 필요". 모델 저장소의 POINT_CONF와 같다.
const reviewConfidence = 0.5;

enum ResultStatus { detecting, ready, saving, failed }

/// 결과 화면에서 약 한 종류의 개수.
class PillCount {
  const PillCount({
    required this.categoryId,
    required this.name,
    required this.count,
    required this.needsReview,
  });

  final int categoryId;
  final String name;
  final int count;
  final bool needsReview;

  PillCount copyWith({required int count}) => PillCount(
    categoryId: categoryId,
    name: name,
    count: count,
    needsReview: needsReview,
  );
}

// TODO(개발 순서 2): 지금 시간대 일정과 비교하고, 약 바꾸기·약 추가를 붙인다.
class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.photo,
    required this._detector,
    required this._medications,
    required this._intakes,
  });

  final Uint8List photo;
  final PillDetector _detector;
  final MedicationRepository _medications;
  final IntakeRepository _intakes;
  bool _disposed = false;

  ResultStatus status = ResultStatus.detecting;
  String? errorMessage;

  List<Detection> detections = const [];
  List<PillCount> pills = const [];

  bool get canSave =>
      status == ResultStatus.ready && pills.any((p) => p.count > 0);

  Future<void> detect() async {
    try {
      await _detector.load();
      detections = await _detector.detect(photo);
      pills = _countByCategory(detections);
      status = ResultStatus.ready;
    } catch (e) {
      errorMessage = '알약을 찾지 못했습니다';
      status = ResultStatus.failed;
    }
    _notify();
  }

  void increment(int index) => _setCount(index, pills[index].count + 1);

  void decrement(int index) {
    if (pills[index].count > 0) _setCount(index, pills[index].count - 1);
  }

  /// 확인한 개수로 복용 기록을 저장한다. 저장했으면 true.
  Future<bool> save() async {
    if (!canSave) return false;
    status = ResultStatus.saving;
    _notify();
    try {
      final counts = <int, int>{};
      for (final pill in pills.where((p) => p.count > 0)) {
        final medication = await _medications.findOrCreateByCategory(
          categoryId: pill.categoryId,
          name: pill.name,
        );
        counts[medication.id] = pill.count;
      }
      await _intakes.addCameraIntake(photo: photo, countsByMedication: counts);
      return true;
    } catch (e) {
      status = ResultStatus.ready;
      errorMessage = '저장하지 못했습니다';
      _notify();
      return false;
    }
  }

  void _setCount(int index, int count) {
    pills = [...pills]..[index] = pills[index].copyWith(count: count);
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

  static List<PillCount> _countByCategory(List<Detection> detections) {
    final byCategory = <int, List<Detection>>{};
    for (final d in detections) {
      byCategory.putIfAbsent(d.categoryId, () => []).add(d);
    }
    return [
      for (final group in byCategory.values)
        PillCount(
          categoryId: group.first.categoryId,
          name: group.first.name,
          count: group.length,
          needsReview: group.any((d) => d.confidence < reviewConfidence),
        ),
    ];
  }
}
