import 'dart:math';

import '../data/models/intake_record.dart';
import '../data/models/medication.dart';
import 'time_format.dart';

/// 하루 일정 하나(약 하나 × 복용 시간 하나)와 그 일정에 먹은 개수.
class DoseSlot {
  const DoseSlot({
    required this.medication,
    required this.time,
    required this.taken,
  });

  final Medication medication;

  /// 자정부터 센 분.
  final int time;
  final int taken;

  int get remaining => max(0, medication.dosePerTake - taken);
  bool get isDone => remaining == 0;
}

class DaySummary {
  const DaySummary({required this.slots, required this.unscheduled});

  /// 시간순, 같은 시간은 약 이름순.
  final List<DoseSlot> slots;

  /// 복용 시간이 없는 약의 기록.
  final List<IntakeRecord> unscheduled;
}

/// 하루 일정과 그날 기록을 맞춘다.
///
/// 기록은 그 약의 복용 시간 중 기록 시각과 가장 가까운 시간에 들어간다.
/// 08:00과 20:00에 먹는 약을 13:00에 기록하면 08:00 일정으로 친다.
DaySummary summarizeDay(
  List<Medication> medications,
  List<IntakeRecord> records,
) {
  final byId = {for (final m in medications) m.id: m};
  final taken = <(int, int), int>{};
  final unscheduled = <IntakeRecord>[];
  for (final record in records) {
    final medication = byId[record.medicationId];
    if (medication == null || medication.times.isEmpty) {
      unscheduled.add(record);
      continue;
    }
    final key = (
      medication.id,
      nearestTime(medication.times, minuteOfDay(record.takenAt)),
    );
    taken[key] = (taken[key] ?? 0) + record.count;
  }
  final slots =
      [
        for (final m in medications)
          for (final t in m.times)
            DoseSlot(medication: m, time: t, taken: taken[(m.id, t)] ?? 0),
      ]..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0
            ? byTime
            : a.medication.name.compareTo(b.medication.name);
      });
  return DaySummary(slots: slots, unscheduled: unscheduled);
}

/// [times] 중 [minute]와 가장 가까운 시각. 같으면 이른 시각.
int nearestTime(Iterable<int> times, int minute) => times.reduce((best, t) {
  final d = (t - minute).abs(), bestD = (best - minute).abs();
  return d < bestD || (d == bestD && t < best) ? t : best;
});

/// 지금 먹어야 할 약: 아직 다 먹지 않은 일정 중 지금과 가장 가까운 시간대의 약과 남은 개수.
///
/// medication_id → 개수. 남은 일정이 없으면 비어 있다.
Map<int, int> dueNow(DaySummary summary, DateTime now) {
  final open = summary.slots.where((s) => !s.isDone).toList();
  if (open.isEmpty) return {};
  final time = nearestTime(open.map((s) => s.time), minuteOfDay(now));
  return {
    for (final s in open)
      if (s.time == time) s.medication.id: s.remaining,
  };
}

enum MatchStatus {
  /// 예정대로.
  ok,

  /// 예정보다 적다.
  missing,

  /// 예정보다 많다.
  extra,

  /// 지금 예정에 없는 약.
  unscheduled,
}

MatchStatus matchStatus({required int expected, required int recognized}) {
  if (expected == 0) return MatchStatus.unscheduled;
  if (recognized == expected) return MatchStatus.ok;
  return recognized < expected ? MatchStatus.missing : MatchStatus.extra;
}
