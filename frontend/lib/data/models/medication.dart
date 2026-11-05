/// 약 종류. 종류가 보상 방식을 정한다(docs/MVP.md 4.1). DB에 이름으로 저장하므로 이름을 바꾸지 않는다.
enum MedicationKind {
  /// 하루 기준량은 사용자가 넣은 하루 권장량([Medication.dailyLimit]).
  supplement('영양제'),

  /// 하루 기준량은 처방에서 정해진다 (하루 횟수 × 1회 알 수).
  prescription('처방약'),

  /// 기준량이 없고 기록만 남긴다.
  asNeeded('필요할 때 먹는 약');

  const MedicationKind(this.label);

  final String label;

  static MedicationKind? fromName(Object? name) =>
      values.where((k) => k.name == name).firstOrNull;
}

class Medication {
  const Medication({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.dosePerTake,
    this.times = const [],
    this.kind,
    this.dailyLimit,
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
    kind: MedicationKind.fromName(map['kind']),
    dailyLimit: map['daily_limit'] as int?,
  );

  final int id;

  /// 탐지 모델이 아는 약(labels.json)의 category_id. 직접 이름을 넣은 약은 null이고 사진으로 인식되지 않는다.
  final int? categoryId;
  final String name;
  final int dosePerTake;

  /// 복용 시간. 자정부터 센 분, 오름차순. 처방 속 회차 시간은 처방([PrescriptionItem.times])에 따로 있다.
  final List<int> times;

  /// 아직 고르지 않았으면 null. 업데이트 전에 등록한 약이 그렇다.
  final MedicationKind? kind;

  /// 영양제의 하루 권장량(알). 영양제가 아니면 null.
  final int? dailyLimit;
}
