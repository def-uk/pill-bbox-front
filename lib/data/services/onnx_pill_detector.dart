import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import '../models/detection.dart';
import '../models/pill_label.dart';
import 'detection_mapper.dart';
import 'pill_detector.dart';
import 'pill_label_service.dart';

@JS('pillbbox.load')
external JSPromise<JSAny?> _load(JSString modelUrl);

@JS('pillbbox.detect')
external JSPromise<JSArray<_Box>> _detect(
  JSUint8Array image,
  JSNumber minConfidence,
);

/// web/pill_detector.js가 돌려주는 박스. 좌표는 원본 이미지 픽셀이다.
extension type _Box(JSObject _) implements JSObject {
  external double get x1;
  external double get y1;
  external double get x2;
  external double get y2;
  external double get confidence;
  external int get classIndex;
}

/// 브라우저에서 onnxruntime-web으로 추론한다. 실제 추론은 web/pill_detector.js가 한다.
class OnnxPillDetector implements PillDetector {
  OnnxPillDetector({required this.modelAsset, required this._labels});

  /// YoloPillDetector와 같은 기준으로 버린다.
  static const minConfidence = 0.25;

  final String modelAsset;
  final PillLabelService _labels;
  Future<List<PillLabel>>? _loaded;

  @override
  Future<void> load() => _loaded ??= _loadModel();

  Future<List<PillLabel>> _loadModel() async {
    try {
      await _load(ui_web.assetManager.getAssetUrl(modelAsset).toJS).toDart;
    } catch (e) {
      _loaded = null;
      throw StateError('모델을 읽지 못했습니다: $modelAsset ($e)');
    }
    return _labels.load();
  }

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async {
    final labels = await (_loaded ??= _loadModel());
    final boxes = await _detect(imageBytes.toJS, minConfidence.toJS).toDart;
    return toDetections([
      for (final b in boxes.toDart)
        {
          'classIndex': b.classIndex,
          'confidence': b.confidence,
          'x1': b.x1,
          'y1': b.y1,
          'x2': b.x2,
          'y2': b.y2,
        },
    ], labels);
  }
}
