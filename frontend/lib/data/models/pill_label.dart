/// 탐지 모델이 아는 약 한 종류. labels.json의 한 줄.
class PillLabel {
  const PillLabel({
    required this.yoloIdx,
    required this.categoryId,
    required this.name,
  });

  factory PillLabel.fromJson(Map<String, Object?> json) => PillLabel(
    yoloIdx: json['yolo_idx']! as int,
    categoryId: json['category_id']! as int,
    name: json['name']! as String,
  );

  final int yoloIdx;
  final int categoryId;
  final String name;
}
