import 'dart:typed_data';
import 'dart:ui';

import '../models/detection.dart';
import 'pill_detector.dart';

/// 입력과 상관없이 고정된 결과를 돌려준다.
///
/// 박스는 [photoAsset](488×640)의 알약 위치에 맞춰 두었다. 다른 사진에서는 박스가 알약과 어긋난다.
class FakePillDetector implements PillDetector {
  FakePillDetector({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  /// 박스를 맞춰 둔 사진. 위젯 테스트도 이 사진을 쓴다.
  static const photoAsset = 'assets/images/test_images/1.jpg';

  static const results = [
    Detection(
      categoryId: 9001,
      name: '샘플약 A (흰색)',
      confidence: 0.93,
      box: Rect.fromLTRB(287, 45, 438, 233),
    ),
    Detection(
      categoryId: 9001,
      name: '샘플약 A (흰색)',
      confidence: 0.88,
      box: Rect.fromLTRB(83, 132, 173, 184),
    ),
    Detection(
      categoryId: 9002,
      name: '샘플약 B (노란색 타원형)',
      confidence: 0.81,
      box: Rect.fromLTRB(307, 349, 410, 569),
    ),
    Detection(
      categoryId: 9003,
      name: '샘플약 C (주황색 타원형)',
      confidence: 0.42,
      box: Rect.fromLTRB(92, 378, 168, 512),
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
