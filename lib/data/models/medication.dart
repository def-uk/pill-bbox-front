class Medication {
  const Medication({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.dosePerTake,
    this.times = const [],
  });

  factory Medication.fromMap(
    Map<String, Object?> map, {
    List<int> times = const [],
  }) => Medication(
    id: map['id']! as int,
    categoryId: map['category_id'] as int?,
    name: map['name']! as String,
    dosePerTake: map['dose_per_take']! as int,
    times: times,
  );

  final int id;

  /// 탐지 모델 56종 중 하나. 직접 등록한 약은 null이고 사진으로 인식되지 않는다.
  final int? categoryId;
  final String name;
  final int dosePerTake;

  /// 복용 시간. 자정부터 센 분, 오름차순.
  final List<int> times;
}
