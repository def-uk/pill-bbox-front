import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/detection.dart';
import '../models/pill_label.dart';
import 'pill_detector.dart';
import 'pill_label_service.dart';

/// ultralytics_yolo 플러그인으로 기기 안에서 추론한다 (Android TFLite, iOS Core ML).
class YoloPillDetector implements PillDetector {
  YoloPillDetector({required this.modelAsset, required this._labels});

  /// 이 값보다 낮은 결과는 버린다. 0.5 미만은 결과 화면에서 "확인 필요"로 보인다.
  static const minConfidence = 0.25;

  final String modelAsset;
  final PillLabelService _labels;
  Future<(YOLO, List<PillLabel>)>? _loaded;

  @override
  Future<void> load() => _loaded ??= _load();

  Future<(YOLO, List<PillLabel>)> _load() async {
    final yolo = YOLO(modelPath: modelAsset, task: YOLOTask.detect);
    if (!await yolo.loadModel()) {
      _loaded = null;
      throw StateError('모델을 읽지 못했습니다: $modelAsset');
    }
    return (yolo, await _labels.load());
  }

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async {
    final (yolo, labels) = await (_loaded ??= _load());
    final output = await yolo.predict(
      imageBytes,
      confidenceThreshold: minConfidence,
    );
    return toDetections([
      for (final box in output['boxes'] as List? ?? const []) box as Map,
    ], labels);
  }
}

/// 플러그인이 돌려준 박스를 앱의 Detection으로 바꾼다.
///
/// ultralytics_yolo 0.7.1은 단일 이미지 결과의 classIndex를 항상 0으로 채우고, iOS는 클래스 이름만 준다.
/// 그래서 원래 박스의 classIndex(Android)가 있으면 그것으로, 없으면 클래스 이름으로 labels.json을 찾는다.
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
