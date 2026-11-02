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

/// 서로 다른 약이라도 이만큼 넘게 겹치면 같은 알약 하나로 본다. 같은 약끼리의 기준(0.45, NMS)보다 높게 두어,
/// 붙어 있는 서로 다른 알약은 지우지 않는다.
const sameObjectIoU = 0.7;

/// 같은 알약에 겹쳐 잡힌 박스를 신뢰도가 가장 높은 하나로 합친다. 지운 박스의 약은 남긴 박스의 후보로 둔다.
///
/// 모델이 알약 하나를 두고 두 약 사이에서 헷갈리면 박스가 두 개 나온다. 둘 다 남기면 1정을 먹었는데
/// 서로 다른 두 약을 1정씩 먹은 것으로 기록된다.
List<Detection> mergeOverlaps(List<Detection> detections) {
  final sorted = [...detections]
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <Detection>[];
  final alternatives = <List<Detection>>[];
  for (final d in sorted) {
    final i = kept.indexWhere((k) => _iou(k.box, d.box) > sameObjectIoU);
    if (i < 0) {
      kept.add(d);
      alternatives.add([]);
    } else if (kept[i].categoryId != d.categoryId &&
        alternatives[i].every((a) => a.categoryId != d.categoryId)) {
      alternatives[i].add(d);
    }
  }
  return [
    for (final (i, k) in kept.indexed)
      Detection(
        categoryId: k.categoryId,
        name: k.name,
        confidence: k.confidence,
        box: k.box,
        alternatives: alternatives[i],
      ),
  ];
}

double _iou(Rect a, Rect b) {
  final overlap = a.intersect(b);
  if (overlap.width <= 0 || overlap.height <= 0) return 0;
  final inter = overlap.width * overlap.height;
  return inter / (a.width * a.height + b.width * b.height - inter);
}
