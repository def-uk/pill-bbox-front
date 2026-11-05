import 'dart:math';

import '../data/models/intake_record.dart';
import '../data/models/medication.dart';
import '../data/models/prescription.dart';
import 'time_format.dart';

/// 회차 시간 앞뒤로 이만큼(분) 안의 기록만 그 회차로 인정한다 (docs/MVP.md 5.2).
const rewardWindowMinutes = 180;

/// 처방 몬스터를 퇴치하면 받는 경험치 (docs/MVP.md 5.3).
const defeatExp = 3;

/// 영양제 일정을 모두 지킨 날 받는 경험치. 영양제를 몇 개 먹든 하루 1.
const supplementDayExp = 1;

/// 처방 하나의 몬스터.
class MonsterState {
  const MonsterState({
    required this.prescription,
    required this.attackDays,
    this.defeatedOn,
  });

  final Prescription prescription;

  /// 체력을 1 깎은 날. 오래된 날부터.
  final List<DateTime> attackDays;

  /// 체력이 0이 된 날. 아직이면 null.
  final DateTime? defeatedOn;

  int get maxHp => prescription.days;
  int get hp => maxHp - attackDays.length;

  /// 깎은 체력.
  int get dealt => attackDays.length;

  bool get isDefeated => defeatedOn != null;

  /// 사용자가 처방을 끝내 몬스터가 물러났다.
  bool get isEnded => prescription.status == PrescriptionStatus.ended;

  /// 아직 싸우는 중: 퇴치하지도 끝내지도 않았다. 처방 기간이 지나도 끝낼 때까지 남는다.
  bool get isActive => !isDefeated && !isEnded;

  bool attackedOn(DateTime day) => attackDays.any((d) => _sameDay(d, day));
}

/// 하루의 보상.
class DayReward {
  const DayReward({
    required this.day,
    required this.supplementsDone,
    required this.attacked,
    required this.exp,
  });

  final DateTime day;

  /// 영양제 일정이 있고, 모두 사진으로 지켰다.
  final bool supplementsDone;

  /// 이날 체력을 깎은 처방(몬스터) id.
  final Set<int> attacked;

  /// 이날 받은 경험치: 영양제 일정 완료, 퇴치, 처방 끝내기.
  final int exp;
}

class RewardState {
  const RewardState({required this.monsters, required this.days});

  static const empty = RewardState(monsters: [], days: {});

  /// 처방마다 하나. 먼저 등록한 처방부터.
  final List<MonsterState> monsters;

  /// 보상이 있는 날. [dateKey] → 보상.
  final Map<String, DayReward> days;

  int get totalExp => days.values.fold(0, (sum, d) => sum + d.exp);

  DayReward? on(DateTime day) => days[dateKey(day)];

  MonsterState? monsterOf(int prescriptionId) =>
      monsters.where((m) => m.prescription.id == prescriptionId).firstOrNull;
}

/// 복용 기록으로 몬스터 체력과 경험치를 처음부터 다시 센다 (docs/MVP.md 5.4).
///
/// 저장해 둔 값을 쌓지 않으므로 기록을 고치거나 지우거나 백업에서 가져와도 같은 결과가 나오고,
/// 같은 날 보상을 두 번 주지 않는다. 날마다:
///
/// 1. 사진 기록(camera)만, 영양제·처방약만 쓴다. 직접 기록과 필요할 때 먹는 약, 종류 없는 약은 보상이 없다.
/// 2. 기록을 회차 시간 앞뒤 [rewardWindowMinutes] 안의 가장 가까운 빈 회차에 한 알씩 채운다.
///    회차마다 그 회차 개수까지, 약마다 하루 기준량까지만 채우고 넘는 것은 버린다.
/// 3. 영양제 회차가 모두 차면 [supplementDayExp].
/// 4. 채운 처방 회차는 먼저 등록한 처방부터 나눠 준다. 한 처방의 그날 회차가 모두 차면 그 몬스터 체력 -1.
///    체력이 0이 되면 퇴치하고 [defeatExp].
/// 5. 끝낸 처방은 끝낸 날에 깎은 체력만큼 경험치를 준다.
///
/// [prescriptions]는 먼저 등록한 것부터 넘긴다 ([PrescriptionRepository.getAll]).
RewardState calculateRewards({
  required List<Medication> medications,
  required List<Prescription> prescriptions,
  required List<IntakeRecord> records,
}) {
  final byId = {for (final m in medications) m.id: m};
  final recordsByDay = <String, List<IntakeRecord>>{};
  for (final r in records) {
    if (r.source != IntakeSource.camera) continue;
    final kind = byId[r.medicationId]?.kind;
    if (kind != MedicationKind.supplement &&
        kind != MedicationKind.prescription) {
      continue;
    }
    recordsByDay.putIfAbsent(dateKey(r.takenAt), () => []).add(r);
  }

  final attacks = {for (final p in prescriptions) p.id: <DateTime>[]};
  final defeatedOn = <int, DateTime>{};
  final days = <String, DayReward>{};

  for (final key in recordsByDay.keys.toList()..sort()) {
    final day = parseDateKey(key)!;
    final fighting = [
      for (final p in prescriptions)
        if (p.countsForRewardOn(day) && !defeatedOn.containsKey(p.id)) p,
    ];
    final filled = _fillSlots(
      _rewardSlots(medications, fighting),
      recordsByDay[key]!,
      byId,
    );

    final supplementSlots = [
      for (final e in filled.entries)
        if (byId[e.key.$1]?.kind == MedicationKind.supplement) e,
    ];
    final supplementsDone =
        supplementSlots.isNotEmpty &&
        supplementSlots.every((e) => e.value.filled >= e.value.capacity);

    final attacked = <int>{};
    final left = {for (final e in filled.entries) e.key: e.value.filled};
    for (final p in fighting) {
      var complete = true;
      for (final item in p.items) {
        for (final t in item.times) {
          final slot = (item.medicationId, t);
          final give = min(item.dosePerTake, left[slot] ?? 0);
          left[slot] = (left[slot] ?? 0) - give;
          if (give < item.dosePerTake) complete = false;
        }
      }
      if (complete && p.items.isNotEmpty) attacked.add(p.id);
    }

    var exp = supplementsDone ? supplementDayExp : 0;
    for (final id in attacked) {
      attacks[id]!.add(day);
      final p = prescriptions.firstWhere((p) => p.id == id);
      if (attacks[id]!.length >= p.days) {
        defeatedOn[id] = day;
        exp += defeatExp;
      }
    }
    if (supplementsDone || attacked.isNotEmpty) {
      days[key] = DayReward(
        day: day,
        supplementsDone: supplementsDone,
        attacked: attacked,
        exp: exp,
      );
    }
  }

  for (final p in prescriptions) {
    final ended = p.endedOn;
    final dealt = attacks[p.id]!.length;
    if (p.status != PrescriptionStatus.ended || ended == null || dealt == 0) {
      continue;
    }
    if (defeatedOn.containsKey(p.id)) continue;
    final key = dateKey(ended);
    final current = days[key];
    days[key] = DayReward(
      day: ended,
      supplementsDone: current?.supplementsDone ?? false,
      attacked: current?.attacked ?? const {},
      exp: (current?.exp ?? 0) + dealt,
    );
  }

  return RewardState(
    monsters: [
      for (final p in prescriptions)
        MonsterState(
          prescription: p,
          attackDays: attacks[p.id]!,
          defeatedOn: defeatedOn[p.id],
        ),
    ],
    days: days,
  );
}

/// 저장 전후 보상이 달라진 것을 한 줄로. 예: "몬스터 체력 -1 · 경험치 +1". 그대로면 null.
String? describeRewardChange(RewardState before, RewardState after) {
  var hit = 0;
  var defeated = 0;
  for (final m in after.monsters) {
    final old = before.monsterOf(m.prescription.id);
    if (old == null) continue;
    if (m.hp < old.hp) hit++;
    if (m.isDefeated && !old.isDefeated) defeated++;
  }
  final exp = after.totalExp - before.totalExp;
  final parts = [
    if (defeated > 0)
      defeated == 1 ? '몬스터 퇴치!' : '몬스터 $defeated마리 퇴치!'
    else if (hit > 0)
      hit == 1 ? '몬스터 체력 -1' : '몬스터 $hit마리 체력 -1',
    if (exp > 0) '경험치 +$exp',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

typedef _Slot = ({int capacity, int filled});

/// 보상에 쓰는 그날 회차: (약, 시간) → 개수. 영양제는 약에 정한 복용 시간, 처방약은 [fighting] 처방의 회차.
/// 같은 약·같은 시간이 겹치면 많은 쪽 하나만 둔다.
Map<(int, int), int> _rewardSlots(
  List<Medication> medications,
  List<Prescription> fighting,
) {
  final slots = <(int, int), int>{};
  for (final m in medications) {
    if (m.kind != MedicationKind.supplement) continue;
    for (final t in m.times) {
      slots[(m.id, t)] = m.dosePerTake;
    }
  }
  final known = {for (final m in medications) m.id: m.kind};
  for (final p in fighting) {
    for (final item in p.items) {
      if (known[item.medicationId] != MedicationKind.prescription) continue;
      for (final t in item.times) {
        final key = (item.medicationId, t);
        slots[key] = max(slots[key] ?? 0, item.dosePerTake);
      }
    }
  }
  return slots;
}

/// 기록을 시각 순서로 한 알씩 회차에 채운다. 회차 시간 앞뒤 [rewardWindowMinutes] 안에서 가장 가까운
/// 빈 회차에 넣고, 약마다 하루 기준량을 넘으면 버린다.
Map<(int, int), _Slot> _fillSlots(
  Map<(int, int), int> capacities,
  List<IntakeRecord> records,
  Map<int, Medication> medications,
) {
  final filled = {for (final k in capacities.keys) k: 0};
  final limits = <int, int>{};
  for (final MapEntry(key: (id, _), value: c) in capacities.entries) {
    limits[id] = (limits[id] ?? 0) + c;
  }
  for (final m in medications.values) {
    if (m.kind == MedicationKind.supplement && m.dailyLimit != null) {
      if (limits.containsKey(m.id)) limits[m.id] = m.dailyLimit!;
    }
  }
  final used = <int, int>{};
  final sorted = [...records]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  for (final r in sorted) {
    final minute = minuteOfDay(r.takenAt);
    for (var unit = 0; unit < r.count; unit++) {
      if ((used[r.medicationId] ?? 0) >= (limits[r.medicationId] ?? 0)) break;
      (int, int)? best;
      for (final key in capacities.keys) {
        final (id, t) = key;
        if (id != r.medicationId) continue;
        if (filled[key]! >= capacities[key]!) continue;
        final d = (t - minute).abs();
        if (d > rewardWindowMinutes) continue;
        if (best == null) {
          best = key;
          continue;
        }
        final bestD = (best.$2 - minute).abs();
        if (d < bestD || (d == bestD && t < best.$2)) best = key;
      }
      if (best == null) break;
      filled[best] = filled[best]! + 1;
      used[r.medicationId] = (used[r.medicationId] ?? 0) + 1;
    }
  }
  return {
    for (final k in capacities.keys)
      k: (capacity: capacities[k]!, filled: filled[k]!),
  };
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
