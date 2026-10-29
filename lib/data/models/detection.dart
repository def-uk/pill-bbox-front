import 'dart:ui';

/// 탐지 모델이 찾은 알약 하나.
class Detection {
  const Detection({
    required this.categoryId,
    required this.name,
    required this.confidence,
    required this.box,
  });

  /// labels.json의 category_id.
  final int categoryId;
  final String name;
  final double confidence;

  /// 원본 이미지 픽셀 좌표.
  final Rect box;
}
