import 'dart:ui';

/// 탐지 모델이 찾은 알약 하나.
class Detection {
  const Detection({
    required this.categoryId,
    required this.name,
    required this.confidence,
    required this.box,
    this.alternatives = const [],
  });

  /// labels.json의 category_id.
  final int categoryId;
  final String name;
  final double confidence;

  /// 원본 이미지 픽셀 좌표.
  final Rect box;

  /// 같은 알약에 겹쳐 잡혔지만 신뢰도가 낮아 지운 다른 약. 모델이 헷갈린 후보다 (mergeOverlaps).
  final List<Detection> alternatives;
}
