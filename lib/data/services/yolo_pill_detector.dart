import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/detection.dart';
import '../models/pill_label.dart';
import 'detection_mapper.dart';
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
