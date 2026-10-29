class Medication {
  const Medication({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.dosePerTake,
  });

  factory Medication.fromMap(Map<String, Object?> map) => Medication(
    id: map['id']! as int,
    categoryId: map['category_id'] as int?,
    name: map['name']! as String,
    dosePerTake: map['dose_per_take']! as int,
  );

  final int id;

  /// 탐지 모델 56종 중 하나. 직접 등록한 약은 null.
  final int? categoryId;
  final String name;
  final int dosePerTake;
}
