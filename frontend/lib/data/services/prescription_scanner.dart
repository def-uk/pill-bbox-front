import 'dart:typed_data';

import 'pill_label_service.dart';

/// 처방전에서 읽은 약 한 줄. 이름은 읽은 그대로라 등록한 약과 다를 수 있다.
class ScannedPrescriptionItem {
  const ScannedPrescriptionItem({required this.name, this.dosePerTake = 1});

  final String name;

  /// 1회 알 수.
  final int dosePerTake;
}

/// 처방전 사진에서 읽은 초안. 사용자가 확인하고 고쳐야 처방이 된다 (docs/DESIGN.md 9.1).
class PrescriptionScan {
  const PrescriptionScan({
    required this.items,
    required this.days,
    required this.times,
  });

  final List<ScannedPrescriptionItem> items;

  /// 처방 일수.
  final int days;

  /// 하루 회차 시간. 자정부터 센 분, 오름차순.
  final List<int> times;

  bool get isEmpty => items.isEmpty;
}

/// 처방전 사진을 읽는다. 사진은 기기 밖으로 보내지 않는다.
abstract interface class PrescriptionScanner {
  Future<PrescriptionScan> scan(Uint8List photo);
}

/// 사진과 상관없이 고정된 초안을 돌려준다. 기기 안 한글 OCR을 붙이기 전까지 흐름을 보여 주는 용도.
///
/// 초안의 약은 사진으로 알아보는 약 목록([PillLabelService])의 앞쪽 셋이라,
/// 등록한 뒤 알약 사진을 찍으면 예정과 비교된다. 5일, 아침·점심·저녁.
class FakePrescriptionScanner implements PrescriptionScanner {
  FakePrescriptionScanner(
    this._labels, {
    this.delay = const Duration(milliseconds: 600),
  });

  final PillLabelService _labels;
  final Duration delay;

  static const days = 5;
  static const times = [8 * 60, 12 * 60 + 30, 19 * 60];

  @override
  Future<PrescriptionScan> scan(Uint8List photo) async {
    final labels = await _labels.load();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return PrescriptionScan(
      items: [
        for (final l in labels.take(3)) ScannedPrescriptionItem(name: l.name),
      ],
      days: days,
      times: times,
    );
  }
}
