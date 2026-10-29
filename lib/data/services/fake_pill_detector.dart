import 'dart:typed_data';
import 'dart:ui';

import '../models/detection.dart';
import 'pill_detector.dart';

/// 입력과 상관없이 고정된 결과를 돌려준다.
///
/// 박스는 assets/images/sample_pills.png(800×600)의 알약 위치에 맞춰 두었다.
class FakePillDetector implements PillDetector {
  FakePillDetector({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  static const results = [
    Detection(
      categoryId: 9001,
      name: '샘플약 A (흰색 원형)',
      confidence: 0.93,
      box: Rect.fromLTRB(140, 190, 260, 310),
    ),
    Detection(
      categoryId: 9001,
      name: '샘플약 A (흰색 원형)',
      confidence: 0.88,
      box: Rect.fromLTRB(340, 140, 460, 260),
    ),
    Detection(
      categoryId: 9002,
      name: '샘플약 B (노란색 타원형)',
      confidence: 0.81,
      box: Rect.fromLTRB(490, 330, 670, 430),
    ),
    Detection(
      categoryId: 9003,
      name: '샘플약 C (분홍색 원형)',
      confidence: 0.42,
      box: Rect.fromLTRB(205, 405, 295, 495),
    ),
  ];

  @override
  Future<void> load() async {}

  @override
  Future<List<Detection>> detect(Uint8List imageBytes) async {
    await Future<void>.delayed(delay);
    return results;
  }
}
