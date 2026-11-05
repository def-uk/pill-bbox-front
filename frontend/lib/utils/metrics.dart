import '../data/models/intake_record.dart';
import '../data/models/medication.dart';
import '../data/models/prescription.dart';
import 'reward_calculator.dart';
import 'time_format.dart';

/// 4주 검증 지표 (docs/MVP.md 9.2). 기록이 기기 안에 있으므로 기기 안에서 센다.
///
/// 약 이름, 병명, 날짜별 기록은 담지 않는다. 테스터가 화면을 캡처해 보낸다.
class TesterMetrics {
  const TesterMetrics({
    required this.start,
    required this.end,
    required this.recordedDays,
    required this.scheduledDays,
    required this.completedDays,
    required this.prescriptions,
    required this.defeated,
    required this.records,
    required this.cameraRecords,
    required this.shareSaves,
  });

  /// 센 기간의 첫날. 기록이 하나도 없으면 null.
  final DateTime? start;
  final DateTime end;

  /// 기록이 하나라도 있는 날.
  final int recordedDays;

  /// 일정(시간을 정한 영양제나 기간 안의 처방)이 있던 날.
  final int scheduledDays;

  /// 일정이 있던 날 중 모두 사진으로 지킨 날.
  final int completedDays;

  /// 등록한 처방과 그중 퇴치한 몬스터.
  final int prescriptions;
  final int defeated;

  /// 기간 안의 복용 기록과 그중 사진 기록.
  final int records;
  final int cameraRecords;

  /// 공유 카드를 저장한 횟수.
  final int shareSaves;

  /// 센 기간의 날 수.
  int get days => start == null ? 0 : end.difference(start!).inDays + 1;
}

/// 오늘까지 [windowDays]일, 단 첫 기록 날부터 센다 (테스트 중간에 시작한 테스터도 같은 기준이 되게).
TesterMetrics computeMetrics({
  required List<Medication> medications,
  required List<Prescription> prescriptions,
  required List<IntakeRecord> records,
  required RewardState rewards,
  required DateTime today,
  required int shareSaves,
  int windowDays = 28,
}) {
  DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
  final end = day(today);
  final defeated = rewards.monsters.where((m) => m.isDefeated).length;
  if (records.isEmpty) {
    return TesterMetrics(
      start: null,
      end: end,
      recordedDays: 0,
      scheduledDays: 0,
      completedDays: 0,
      prescriptions: prescriptions.length,
      defeated: defeated,
      records: 0,
      cameraRecords: 0,
      shareSaves: shareSaves,
    );
  }
  final first = records
      .map((r) => day(r.takenAt))
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final windowStart = DateTime(end.year, end.month, end.day - windowDays + 1);
  final start = first.isAfter(windowStart) ? first : windowStart;

  bool inWindow(DateTime t) => !day(t).isBefore(start) && !day(t).isAfter(end);
  final windowRecords = [
    for (final r in records)
      if (inWindow(r.takenAt)) r,
  ];
  final hasSupplementSchedule = medications.any(
    (m) => m.kind == MedicationKind.supplement && m.times.isNotEmpty,
  );
  var scheduled = 0, completed = 0;
  for (
    var d = start;
    !d.isAfter(end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final hasSchedule =
        hasSupplementSchedule ||
        prescriptions.any((p) => p.countsForRewardOn(d));
    if (!hasSchedule) continue;
    scheduled++;
    if (rewards.on(d)?.scheduleDone ?? false) completed++;
  }
  return TesterMetrics(
    start: start,
    end: end,
    recordedDays: {for (final r in windowRecords) dateKey(r.takenAt)}.length,
    scheduledDays: scheduled,
    completedDays: completed,
    prescriptions: prescriptions.length,
    defeated: defeated,
    records: windowRecords.length,
    cameraRecords: windowRecords
        .where((r) => r.source == IntakeSource.camera)
        .length,
    shareSaves: shareSaves,
  );
}
