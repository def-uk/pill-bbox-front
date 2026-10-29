enum IntakeSource { camera, manual }

class IntakeRecord {
  const IntakeRecord({
    required this.id,
    required this.medicationId,
    required this.takenAt,
    required this.count,
    required this.source,
    required this.photoPath,
  });

  factory IntakeRecord.fromMap(Map<String, Object?> map) => IntakeRecord(
    id: map['id']! as int,
    medicationId: map['medication_id']! as int,
    takenAt: DateTime.fromMillisecondsSinceEpoch(map['taken_at']! as int),
    count: map['count']! as int,
    source: IntakeSource.values.byName(map['source']! as String),
    photoPath: map['photo_path'] as String?,
  );

  final int id;
  final int medicationId;
  final DateTime takenAt;
  final int count;
  final IntakeSource source;

  /// 앱 문서 폴더 기준 상대 경로. 수동 기록은 null.
  final String? photoPath;
}
