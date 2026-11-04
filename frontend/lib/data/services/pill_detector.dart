import 'dart:typed_data';

import '../models/detection.dart';

/// 이 값보다 신뢰도가 낮은 결과는 약으로 보지 않는다. 모델 저장소의 평가 기준(POINT_CONF)과 같다.
/// 버린 알약은 물체 찾기(findObjects)가 "알 수 없는 물체"로 잡아, 사용자가 무엇인지 고를 수 있다.
const minDetectionConfidence = 0.5;

/// 알약 탐지기. 모델 확정 전에는 FakePillDetector를 쓴다 (docs/DESIGN.md 3.4).
abstract class PillDetector {
  /// 모델을 읽는다. 여러 번 불러도 한 번만 읽어야 한다.
  Future<void> load();

  Future<List<Detection>> detect(Uint8List imageBytes);
}
