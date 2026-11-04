import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/detection.dart';
import 'package:pillbbox/data/models/pill_label.dart';
import 'package:pillbbox/data/services/detection_mapper.dart';

const labels = [
  PillLabel(yoloIdx: 0, categoryId: 1899, name: '보령부스파정 5mg'),
  PillLabel(yoloIdx: 1, categoryId: 3350, name: '뮤테란캡슐 100mg'),
];

Map<String, Object> box(
  String name, {
  int? classIndex,
  double confidence = 0.9,
}) => {
  'class': name,
  'className': name,
  'classIndex': ?classIndex,
  'confidence': confidence,
  'x1': 10.0,
  'y1': 20.0,
  'x2': 110.0,
  'y2': 220.0,
};

void main() {
  test('Android는 classIndex로 labels.json을 찾는다', () {
    final [d] = toDetections([box('anything', classIndex: 1)], labels);
    expect((d.categoryId, d.name), (3350, '뮤테란캡슐 100mg'));
    expect(d.box, const Rect.fromLTRB(10, 20, 110, 220));
    expect(d.confidence, 0.9);
  });

  test('iOS는 클래스 이름으로 찾고, 이름이 category_id 숫자여도 찾는다', () {
    final detections = toDetections([box('보령부스파정 5mg'), box('3350')], labels);
    expect([for (final d in detections) d.categoryId], [1899, 3350]);
  });

  test('labels.json에 없는 클래스는 이름마다 다른 음수 category_id로 남긴다', () {
    final detections = toDetections([
      box('bus'),
      box('person'),
      box('bus'),
    ], labels);
    expect(
      [for (final d in detections) (d.categoryId, d.name)],
      [(-1, 'bus'), (-2, 'person'), (-1, 'bus')],
    );
  });

  group('mergeOverlaps', () {
    Detection pill(int id, double confidence, Rect box) => Detection(
      categoryId: id,
      name: '약 $id',
      confidence: confidence,
      box: box,
    );
    const here = Rect.fromLTRB(0, 0, 100, 100);

    test('알약 하나에 다른 약이 겹쳐 잡히면 신뢰도가 높은 쪽만 남기고 다른 약은 후보로 둔다', () {
      final [kept] = mergeOverlaps([
        pill(2, 0.6, const Rect.fromLTRB(4, 2, 102, 98)),
        pill(1, 0.9, here),
      ]);

      expect(kept.categoryId, 1);
      expect([for (final a in kept.alternatives) a.categoryId], [2]);
    });

    test('붙어 있는 서로 다른 알약은 조금 겹쳐도 둘 다 남긴다', () {
      final merged = mergeOverlaps([
        pill(1, 0.9, here),
        pill(2, 0.8, const Rect.fromLTRB(60, 0, 160, 100)),
      ]);

      expect([for (final d in merged) d.categoryId], [1, 2]);
      expect(merged.every((d) => d.alternatives.isEmpty), isTrue);
    });

    test('같은 약이 겹치면 하나만 남기고, 후보에는 같은 약을 두 번 넣지 않는다', () {
      final [kept] = mergeOverlaps([
        pill(1, 0.9, here),
        pill(2, 0.7, here),
        pill(1, 0.6, here),
        pill(2, 0.55, here),
      ]);

      expect(kept.categoryId, 1);
      expect([for (final a in kept.alternatives) a.categoryId], [2]);
    });
  });
}
