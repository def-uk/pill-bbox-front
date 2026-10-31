import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/pill_label.dart';
import 'package:pillbbox/data/services/yolo_pill_detector.dart';

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
}
