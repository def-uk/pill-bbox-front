import 'dart:ui';

import '../models/detection.dart';
import '../models/pill_label.dart';

/// 탐지기가 돌려준 박스를 앱의 Detection으로 바꾼다. 박스 좌표는 원본 이미지 픽셀이다.
///
/// ultralytics_yolo 0.7.1은 단일 이미지 결과의 classIndex를 항상 0으로 채우고, iOS는 클래스 이름만 준다.
/// 그래서 원래 박스의 classIndex(Android, 웹)가 있으면 그것으로, 없으면 클래스 이름으로 labels.json을 찾는다.
/// 모델의 클래스 이름이 category_id 숫자여도 찾는다.
///
/// labels.json에 없는 클래스는 모델 이름을 그대로 쓰고, 등록할 수 없는 약이 되도록 이름마다 음수
/// category_id를 준다. 모델과 labels.json 버전이 어긋났을 때 결과를 숨기지 않으려는 것이다.
List<Detection> toDetections(List<Map> boxes, List<PillLabel> labels) {
  final byIndex = {for (final l in labels) l.yoloIdx: l};
  final byName = {for (final l in labels) l.name: l};
  final byCategory = {for (final l in labels) l.categoryId: l};
  final unknownIds = <String, int>{};

  Detection convert(Map box) {
    final name = (box['className'] ?? box['class'] ?? '') as String;
    final label = switch (box['classIndex']) {
      final int index => byIndex[index],
      _ => byName[name] ?? byCategory[int.tryParse(name)],
    };
    double value(String key) => (box[key] as num).toDouble();
    return Detection(
      categoryId:
          label?.categoryId ??
          unknownIds.putIfAbsent(name, () => -1 - unknownIds.length),
      name: label?.name ?? name,
      confidence: value('confidence'),
      box: Rect.fromLTRB(value('x1'), value('y1'), value('x2'), value('y2')),
    );
  }

  return boxes.map(convert).toList();
}
