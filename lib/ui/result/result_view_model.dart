import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../data/models/appearance.dart';
import '../../data/models/detection.dart';
import '../../data/models/medication.dart';
import '../../data/models/pill_label.dart';
import '../../data/repositories/intake_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/services/pill_detector.dart';
import '../../data/services/pill_label_service.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/object_finder.dart';

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

  /// 등록한 약. 처음 기록하는 약이면 null이고, 저장할 때 등록한다.
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

/// 약 바꾸기·약 추가에서 고를 수 있는 약. 등록한 약이거나, 모델이 아는 약 중 아직 등록하지 않은 약이거나,
/// 사용자가 이름을 직접 넣은 약([isCustom]).
class PillChoice {
  const PillChoice({this.medication, this.categoryId, required this.name})
    : isCustom = false;

  /// 이름만 있는 새 약. 모델이 모르는 약이라 다음 사진에서는 색·모양으로만 추천한다.
  const PillChoice.custom(this.name)
    : medication = null,
      categoryId = null,
      isCustom = true;

  final Medication? medication;
  final int? categoryId;
  final String name;
  final bool isCustom;
}

/// 모델은 알약으로 보지 않았지만 배경과 다른 색의 물체. 사용자가 무엇인지 고르면 기록한다.
class UnknownObject {
  const UnknownObject({
    required this.number,
    required this.box,
    required this.appearance,
    this.suggestion,
  });

  /// 화면에 보이는 번호. 1부터.
  final int number;

  /// 원본 이미지 픽셀 좌표.
  final Rect box;
  final Appearance appearance;

  /// 예전에 고른 약 중 색·모양이 가장 비슷한 약. 비슷한 약이 없으면 null.
  final Medication? suggestion;
}

/// 물체에 고른 약. 등록한 약이면 [medicationId], 처음 기록하는 약이면 [key](처음 기록하는 약 줄의 category_id).
typedef _Target = ({int? medicationId, int? key});

class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.photo,
    required this._detector,
    required this._medications,
    required this._intakes,
    required this._labels,
    Future<List<FoundObject>> Function(Uint8List photo)? objectFinder,
    DateTime Function()? now,
  }) : _findObjects = objectFinder ?? ((photo) => compute(findObjects, photo)),
       _now = now ?? DateTime.now;

  final Uint8List photo;
  final PillDetector _detector;
  final MedicationRepository _medications;
  final IntakeRepository _intakes;
  final PillLabelService _labels;
  final Future<List<FoundObject>> Function(Uint8List photo) _findObjects;
  final DateTime Function() _now;
  bool _disposed = false;

  ResultStatus status = ResultStatus.detecting;
  String? errorMessage;
  List<Detection> detections = const [];

  /// 모델이 알약으로 보지 않은 물체 중 아직 무엇인지 고르지 않은 것.
  List<UnknownObject> unknowns = const [];

  /// 모델이 알약을 하나도 찾지 못했다.
  bool get noPills => detections.isEmpty;

  /// 등록한 약 전부.
  List<Medication> medications = const [];

  /// 모델이 아는 약 전부.
  List<PillLabel> _allLabels = const [];

  Map<int, int> _due = {};
  final _counts = <int, int>{};
  final _review = <int>{};

  /// 등록한 약 줄의 순서. medication_id.
  final _order = <int>[];

  /// 처음 기록하는 약. category_id → 줄. 이름을 직접 넣은 약은 [_customKeyStart]부터 줄어드는 키를 쓴다.
  final _unregistered = <int, ResultLine>{};

  /// toDetections가 labels.json에 없는 클래스에 주는 음수(-1, -2, ...)와 겹치지 않게 한다.
  static const _customKeyStart = -1000000;
  int _nextCustomKey = _customKeyStart;

  /// 물체에 고른 약과 그 물체의 색·모양. 저장할 때 남겨 다음 사진에서 추천한다.
  final _picked = <(_Target, Appearance)>[];

  /// 약 바꾸기·약 추가에서 고를 수 있는 약. 등록한 약 먼저.
  List<PillChoice> get choices {
    final registered = {for (final m in medications) m.categoryId};
    return [
      for (final m in medications)
        PillChoice(medication: m, categoryId: m.categoryId, name: m.name),
      for (final l in _unregistered.values)
        if (l.categoryId! <= _customKeyStart)
          PillChoice(categoryId: l.categoryId, name: l.name),
      for (final l in _allLabels)
        if (!registered.contains(l.categoryId))
          PillChoice(categoryId: l.categoryId, name: l.name),
    ];
  }

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

  bool get canSave =>
      status == ResultStatus.ready &&
      (_counts.values.any((c) => c > 0) ||
          _unregistered.values.any((l) => l.count > 0));

  Future<void> detect() async {
    try {
      final now = _now();
      medications = await _medications.getAll();
      _allLabels = await _labels.load();
      final records = await _intakes.recordsOn(now);
      _due = dueNow(summarizeDay(medications, records), now);

      await _detector.load();
      detections = await _detector.detect(photo);
      _arrange(detections);
      unknowns = await _unknownObjects();
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

  /// [line]의 개수를 [choice]로 옮긴다. 모델이 다른 약으로 인식했을 때 쓴다.
  void changeMedication(ResultLine line, PillChoice choice) {
    choice = _resolve(choice);
    final same = choice.medication == null
        ? line.medication == null && line.categoryId == choice.categoryId
        : line.medication?.id == choice.medication!.id;
    if (same) return;
    if (line.medication case final from?) {
      _counts.remove(from.id);
      _review.remove(from.id);
      if (!_due.containsKey(from.id)) _order.remove(from.id);
    } else {
      _unregistered.remove(line.categoryId);
    }
    _retarget(_targetOfLine(line), _targetOf(choice));
    _addCount(choice, line.count);
    _notify();
  }

  /// 모델이 못 찾은 약을 1정 더한다.
  void addMedication(PillChoice choice) {
    _addCount(_resolve(choice), 1);
    _notify();
  }

  /// [object]가 [choice] 약이라고 정한다. 1정으로 더하고, 저장할 때 색·모양을 남긴다.
  void identify(UnknownObject object, PillChoice choice) {
    choice = _resolve(choice);
    _addCount(choice, 1);
    _picked.add((_targetOf(choice), object.appearance));
    unknowns = [...unknowns]..remove(object);
    _notify();
  }

  /// [object]는 약이 아니라고 보고 목록에서 뺀다.
  void dismiss(UnknownObject object) {
    unknowns = [...unknowns]..remove(object);
    _notify();
  }

  /// 확인한 개수로 복용 기록을 저장한다. 처음 기록하는 약은 먼저 등록한다. 저장했으면 true.
  Future<bool> save() async {
    if (!canSave) return false;
    status = ResultStatus.saving;
    _notify();
    try {
      await _registerNewMedications();
      await _intakes.addCameraIntake(photo: photo, countsByMedication: _counts);
      await _saveAppearances();
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

  /// 모델 박스와 절반 넘게 겹치지 않는 물체를 번호를 붙여 돌려준다. 물체 찾기가 실패해도 탐지 결과는 보여 준다.
  Future<List<UnknownObject>> _unknownObjects() async {
    final List<FoundObject> objects;
    final List<(int, Appearance)> remembered;
    try {
      objects = await _findObjects(photo);
      remembered = await _medications.appearances();
    } catch (_) {
      return const [];
    }
    bool coveredByModel(Rect box) => detections.any((d) {
      final overlap = d.box.intersect(box);
      return !overlap.isEmpty &&
          overlap.width * overlap.height > 0.5 * box.width * box.height;
    });
    final byId = {for (final m in medications) m.id: m};
    Medication? similar(Appearance appearance) {
      Medication? best;
      var bestDistance = Appearance.similarDistance;
      for (final (id, known) in remembered) {
        final distance = appearance.distanceTo(known);
        if (distance < bestDistance && byId[id] != null) {
          best = byId[id];
          bestDistance = distance;
        }
      }
      return best;
    }

    final unknown = [
      for (final o in objects)
        if (!coveredByModel(o.box)) o,
    ]..sort((a, b) => a.box.top.compareTo(b.box.top));
    return [
      for (final (i, o) in unknown.indexed)
        UnknownObject(
          number: i + 1,
          box: o.box,
          appearance: o.appearance,
          suggestion: similar(o.appearance),
        ),
    ];
  }

  /// 이름을 직접 넣은 약을 등록한 약이나 이번에 처음 기록하는 같은 이름의 약으로, 없으면 새 키로 바꾼다.
  PillChoice _resolve(PillChoice choice) {
    if (!choice.isCustom) return choice;
    final name = choice.name.trim();
    for (final m in medications) {
      if (m.name == name) {
        return PillChoice(medication: m, categoryId: m.categoryId, name: name);
      }
    }
    for (final l in _unregistered.values) {
      if (l.name == name) {
        return PillChoice(categoryId: l.categoryId, name: name);
      }
    }
    return PillChoice(categoryId: _nextCustomKey--, name: name);
  }

  static _Target _targetOf(PillChoice c) => (
    medicationId: c.medication?.id,
    key: c.medication == null ? c.categoryId : null,
  );

  static _Target _targetOfLine(ResultLine l) => (
    medicationId: l.medication?.id,
    key: l.medication == null ? l.categoryId : null,
  );

  void _retarget(_Target from, _Target to) {
    for (final (i, (target, appearance)) in [..._picked].indexed) {
      if (target == from) _picked[i] = (to, appearance);
    }
  }

  /// 이번에 기록한 약에 고른 물체의 색·모양을 남긴다. 실패해도 기록은 이미 저장됐으므로 넘어간다.
  Future<void> _saveAppearances() async {
    try {
      for (final ((:medicationId, key: _), appearance) in _picked) {
        if (medicationId != null && (_counts[medicationId] ?? 0) > 0) {
          await _medications.addAppearance(medicationId, appearance);
        }
      }
    } catch (_) {}
    _picked.clear();
  }

  void _addCount(PillChoice choice, int count) {
    if (choice.medication case final medication?) {
      _counts[medication.id] = (_counts[medication.id] ?? 0) + count;
      if (!_order.contains(medication.id)) _order.add(medication.id);
      return;
    }
    final current = _unregistered[choice.categoryId];
    _unregistered[choice.categoryId!] = ResultLine(
      medication: null,
      categoryId: choice.categoryId,
      name: choice.name,
      count: (current?.count ?? 0) + count,
      expected: 0,
      needsReview: current?.needsReview ?? false,
    );
  }

  /// 처음 기록하는 약을 복용 시간 없이 등록하고 등록한 약 줄로 옮긴다. 1회 수량은 이번에 확인한 개수.
  ///
  /// 기록 저장이 실패해 다시 저장할 때 같은 약을 또 등록하지 않도록 바로 옮긴다.
  Future<void> _registerNewMedications() async {
    final lines = [..._unregistered.values.where((l) => l.count > 0)];
    if (lines.isEmpty) return;
    for (final line in lines) {
      final id = await _medications.save(
        // 음수는 labels.json에 없는 클래스라 인식 대상으로 등록하지 않는다 (toDetections).
        categoryId: line.categoryId! < 0 ? null : line.categoryId,
        name: line.name,
        dosePerTake: line.count,
        times: const [],
      );
      _unregistered.remove(line.categoryId);
      _retarget(
        (medicationId: null, key: line.categoryId),
        (medicationId: id, key: null),
      );
      _counts[id] = line.count;
      _order.add(id);
      if (line.needsReview) _review.add(id);
    }
    medications = await _medications.getAll();
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
