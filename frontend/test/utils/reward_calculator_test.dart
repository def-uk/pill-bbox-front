import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/intake_record.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/utils/reward_calculator.dart';

Medication med(
  int id,
  MedicationKind? kind, {
  int dose = 1,
  List<int> times = const [],
  int? dailyLimit,
}) => Medication(
  id: id,
  categoryId: null,
  name: '약$id',
  dosePerTake: dose,
  times: times,
  kind: kind,
  dailyLimit: dailyLimit,
);

Prescription rx(
  int id,
  List<PrescriptionItem> items, {
  int days = 28,
  DateTime? start,
  PrescriptionStatus status = PrescriptionStatus.active,
  DateTime? endedOn,
}) => Prescription(
  id: id,
  startDate: start ?? DateTime(2026, 11, 1),
  days: days,
  status: status,
  items: items,
  endedOn: endedOn,
);

PrescriptionItem item(int medicationId, List<int> hours, {int dose = 1}) =>
    PrescriptionItem(
      medicationId: medicationId,
      dosePerTake: dose,
      times: [for (final h in hours) h * 60],
    );

var _nextId = 1;
IntakeRecord rec(
  int medicationId,
  int day,
  int hour, {
  int minute = 0,
  int count = 1,
  IntakeSource source = IntakeSource.camera,
}) => IntakeRecord(
  id: _nextId++,
  medicationId: medicationId,
  takenAt: DateTime(2026, 11, day, hour, minute),
  count: count,
  source: source,
  photoPath: null,
);

void main() {
  // 처방약 X: 08:00, 20:00에 1알.
  final x = med(1, MedicationKind.prescription);
  final acne = rx(10, [
    item(1, [8, 20]),
  ]);

  RewardState calc(
    List<IntakeRecord> records, {
    List<Medication>? medications,
    List<Prescription>? prescriptions,
  }) => calculateRewards(
    medications: medications ?? [x],
    prescriptions: prescriptions ?? [acne],
    records: records,
  );

  test('그날 회차를 모두 사진으로 기록하면 체력 -1, 하루 최대 1', () {
    final state = calc([
      rec(1, 1, 8),
      rec(1, 1, 20),
      // 같은 날 또 찍어도 더 깎이지 않는다.
      rec(1, 1, 8, minute: 5),
      rec(1, 1, 20, minute: 5),
    ]);
    final monster = state.monsterOf(10)!;
    expect((monster.maxHp, monster.hp), (28, 27));
    expect(monster.attackedOn(DateTime(2026, 11, 1, 12)), isTrue);
    expect(state.on(DateTime(2026, 11, 1))!.attacked, {10});
  });

  test('사진 없는 기록(manual)은 체력·경험치를 바꾸지 않는다', () {
    final state = calc([
      rec(1, 1, 8, source: IntakeSource.manual),
      rec(1, 1, 20),
    ]);
    expect(state.monsterOf(10)!.hp, 28);
    expect(state.days, isEmpty);
    expect(state.totalExp, 0);
  });

  test('회차를 하나라도 놓친 날은 체력이 줄지 않는다', () {
    expect(calc([rec(1, 1, 8)]).monsterOf(10)!.hp, 28);
  });

  test('회차 시간 앞뒤 3시간 밖의 기록은 인정하지 않는다. 아침 약을 저녁에 몰아 먹어도 보상 없음', () {
    expect(calc([rec(1, 1, 11), rec(1, 1, 17)]).monsterOf(10)!.hp, 27);
    expect(
      calc([rec(1, 1, 11, minute: 1), rec(1, 1, 20)]).monsterOf(10)!.hp,
      28,
    );
    expect(calc([rec(1, 1, 20, count: 2)]).monsterOf(10)!.hp, 28);
    expect(calc([rec(1, 1, 8, count: 2)]).monsterOf(10)!.hp, 28);
  });

  test('하루 기준량을 넘는 영양제 기록은 보상에 들어가지 않는다', () {
    // 08:00, 09:00에 1알씩 정했지만 하루 권장량은 1알.
    final vitamin = med(
      2,
      MedicationKind.supplement,
      times: [8 * 60, 9 * 60],
      dailyLimit: 1,
    );
    final state = calc(
      [rec(2, 1, 8), rec(2, 1, 9)],
      medications: [vitamin],
      prescriptions: [],
    );
    expect(state.totalExp, 0);

    final ok = med(
      2,
      MedicationKind.supplement,
      times: [8 * 60],
      dailyLimit: 1,
    );
    expect(
      calc(
        [rec(2, 1, 8, count: 3)],
        medications: [ok],
        prescriptions: [],
      ).totalExp,
      1,
    );
  });

  test('영양제 일정을 모두 지킨 날은 영양제가 몇 개든 경험치 1', () {
    final d = med(2, MedicationKind.supplement, times: [8 * 60], dailyLimit: 1);
    final probiotic = med(
      3,
      MedicationKind.supplement,
      dose: 2,
      times: [8 * 60],
      dailyLimit: 2,
    );
    final medications = [d, probiotic];
    RewardState on(List<IntakeRecord> records) =>
        calc(records, medications: medications, prescriptions: []);

    expect(on([rec(2, 1, 8), rec(3, 1, 8, count: 2)]).totalExp, 1);
    expect(on([rec(2, 1, 8), rec(3, 1, 8)]).totalExp, 0);
    expect(
      on([
        rec(2, 1, 8),
        rec(3, 1, 8, count: 2),
        rec(2, 2, 8),
        rec(3, 2, 9, count: 2),
      ]).totalExp,
      2,
    );
  });

  test('필요할 때 먹는 약과 종류 없는 약은 보상이 없다', () {
    final painkiller = med(4, MedicationKind.asNeeded, times: [8 * 60]);
    final untyped = med(5, null, times: [8 * 60]);
    final state = calc(
      [rec(4, 1, 8), rec(5, 1, 8)],
      medications: [painkiller, untyped],
      prescriptions: [],
    );
    expect(state.days, isEmpty);
  });

  test('같은 약이 든 처방 둘이 겹치면 먼저 등록한 처방의 몬스터부터 깎는다', () {
    final y = med(2, MedicationKind.prescription);
    final first = rx(10, [
      item(1, [8]),
    ]);
    final second = rx(11, [
      item(1, [8]),
      item(2, [8]),
    ], start: DateTime(2026, 11, 2));
    RewardState on(List<IntakeRecord> records) =>
        calc(records, medications: [x, y], prescriptions: [first, second]);

    // 하루 기준량은 하나만: X를 1알 먹으면 먼저 등록한 처방만 깎인다.
    final day2 = on([rec(1, 2, 8), rec(2, 2, 8)]);
    expect(day2.on(DateTime(2026, 11, 2))!.attacked, {10});
    expect((day2.monsterOf(10)!.hp, day2.monsterOf(11)!.hp), (27, 28));

    // 2알 먹어도 하루 기준량(겹친 회차는 1알)을 넘으므로 나중 처방은 깎이지 않는다.
    final twice = on([rec(1, 2, 8, count: 2), rec(2, 2, 8)]);
    expect(twice.monsterOf(11)!.hp, 28);

    // 먼저 처방이 끝나면 나중 처방이 깎인다.
    final afterEnd = calc(
      [rec(1, 3, 8), rec(2, 3, 8)],
      medications: [x, y],
      prescriptions: [
        rx(
          10,
          [
            item(1, [8]),
          ],
          status: PrescriptionStatus.ended,
          endedOn: DateTime(2026, 11, 2),
        ),
        second,
      ],
    );
    expect(afterEnd.on(DateTime(2026, 11, 3))!.attacked, {11});
  });

  test('기록을 지우면 그날 보상이 사라지고, 같은 기록이면 순서와 상관없이 결과가 같다', () {
    final records = [rec(1, 1, 8), rec(1, 1, 20), rec(1, 2, 8), rec(1, 2, 20)];
    final full = calc(records);
    expect(full.monsterOf(10)!.hp, 26);

    final deleted = calc([...records]..removeAt(3));
    expect(deleted.monsterOf(10)!.hp, 27);
    expect(deleted.on(DateTime(2026, 11, 2)), isNull);

    final restored = calc(records.reversed.toList());
    expect(restored.monsterOf(10)!.hp, 26);
    expect(restored.totalExp, full.totalExp);
  });

  test('28일 처방을 28일 동안 채우면 체력 0이 되어 퇴치하고 경험치 3', () {
    final records = [
      for (var day = 1; day <= 28; day++) ...[rec(1, day, 8), rec(1, day, 20)],
      // 기간이 지난 뒤 기록은 보상이 없다.
      rec(1, 29, 8),
      rec(1, 29, 20),
    ];
    final state = calc(records);
    final monster = state.monsterOf(10)!;
    expect(monster.hp, 0);
    expect(monster.isDefeated, isTrue);
    expect(monster.isActive, isFalse);
    expect(monster.defeatedOn, DateTime(2026, 11, 28));
    expect(state.on(DateTime(2026, 11, 28))!.exp, defeatExp);
    expect(state.on(DateTime(2026, 11, 29)), isNull);
    expect(state.totalExp, defeatExp);
  });

  test('처방을 끝내면 끝낸 날까지만 깎고, 깎은 체력만큼 끝낸 날 경험치를 받는다', () {
    final ended = rx(
      10,
      [
        item(1, [8, 20]),
      ],
      status: PrescriptionStatus.ended,
      endedOn: DateTime(2026, 11, 5),
    );
    final state = calc(
      [
        for (final day in [1, 2, 5, 6]) ...[rec(1, day, 8), rec(1, day, 20)],
      ],
      prescriptions: [ended],
    );
    final monster = state.monsterOf(10)!;
    expect(monster.dealt, 3);
    expect((monster.isEnded, monster.isDefeated), (true, false));
    expect(state.on(DateTime(2026, 11, 5))!.exp, 3);
    expect(state.on(DateTime(2026, 11, 6)), isNull);
    expect(state.totalExp, 3);
  });

  test('저장 전후로 체력이 준 몬스터와 경험치 변화를 비교한다', () {
    final before = calc([rec(1, 1, 8)]);
    final after = calc([rec(1, 1, 8), rec(1, 1, 20)]);
    final outcome = compareRewards(before, after)!;
    expect(
      [for (final m in outcome.monsters) (m.before.hp, m.after.hp)],
      [(28, 27)],
    );
    expect(outcome.expGained, 0);
    expect(compareRewards(after, after), isNull);

    final vitamin = med(2, MedicationKind.supplement, times: [8 * 60]);
    final supplementOnly = compareRewards(
      calc(const [], medications: [vitamin], prescriptions: []),
      calc([rec(2, 1, 8)], medications: [vitamin], prescriptions: []),
    )!;
    expect(supplementOnly.monsters, isEmpty);
    expect((supplementOnly.expBefore, supplementOnly.expAfter), (0, 1));

    final short = rx(10, [
      item(1, [8]),
    ], days: 1);
    final defeat = compareRewards(
      calc(const [], prescriptions: [short]),
      calc([rec(1, 1, 8)], prescriptions: [short]),
    )!;
    expect(defeat.monsters.single.after.isDefeated, isTrue);
    expect(defeat.expGained, defeatExp);
  });
}
