import 'dart:typed_data';

import '../models/detection.dart';

/// 알약 탐지기. 모델 확정 전에는 FakePillDetector를 쓴다 (docs/DESIGN.md 3.4).
abstract class PillDetector {
  /// 모델을 읽는다. 여러 번 불러도 한 번만 읽어야 한다.
  Future<void> load();

  Future<List<Detection>> detect(Uint8List imageBytes);
}
