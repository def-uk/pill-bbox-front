import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/intake_record.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/utils/intake_matcher.dart';

const a = Medication(
  id: 1,
  categoryId: 1,
  name: 'A',
  dosePerTake: 2,
  times: [8 * 60, 20 * 60],
);
const b = Medication(
  id: 2,
  categoryId: 2,
  name: 'B',
  dosePerTake: 1,
  times: [8 * 60],
);
const c = Medication(id: 3, categoryId: null, name: 'C', dosePerTake: 1);

IntakeRecord record(Medication m, int hour, int count, {int minute = 0}) =>
    IntakeRecord(
      id: 0,
      medicationId: m.id,
      takenAt: DateTime(2026, 10, 30, hour, minute),
      count: count,
      source: IntakeSource.camera,
      photoPath: null,
    );

void main() {
  test('기록을 그 약의 가장 가까운 복용 시간에 넣는다', () {
    final summary = summarizeDay(
      [a, b, c],
      [
        record(a, 9, 1),
        record(a, 13, 1, minute: 59), // 08:00과 20:00 중 08:00에 더 가깝다
        record(b, 21, 1), // B는 08:00뿐이다
        record(c, 12, 1), // 복용 시간이 없는 약
      ],
    );

    expect(
      [
        for (final s in summary.slots)
          (s.time, s.medication.name, s.taken, s.isDone),
      ],
      [(480, 'A', 2, true), (480, 'B', 1, true), (1200, 'A', 0, false)],
    );
    expect([for (final r in summary.unscheduled) r.medicationId], [c.id]);
  });

  test('가운데 시각은 이른 시간으로 친다', () {
    expect(nearestTime([480, 1200], 840), 480);
    expect(nearestTime([480, 1200], 841), 1200);
  });

  test('지금 먹을 약은 아직 다 먹지 않은 일정 중 가장 가까운 시간대다', () {
    final morning = DateTime(2026, 10, 30, 9);
    expect(dueNow(summarizeDay([a, b], []), morning), {a.id: 2, b.id: 1});
    expect(dueNow(summarizeDay([a, b], [record(a, 8, 1)]), morning), {
      a.id: 1,
      b.id: 1,
    }, reason: '남은 개수만');
    expect(
      dueNow(summarizeDay([a, b], [record(a, 8, 2), record(b, 8, 1)]), morning),
      {a.id: 2},
      reason: '아침을 다 먹었으면 저녁 일정',
    );
    expect(dueNow(summarizeDay([c], []), morning), isEmpty);
  });

  test('예정과 인식 개수를 비교한다', () {
    expect(matchStatus(expected: 2, recognized: 2), MatchStatus.ok);
    expect(matchStatus(expected: 2, recognized: 1), MatchStatus.missing);
    expect(matchStatus(expected: 1, recognized: 2), MatchStatus.extra);
    expect(matchStatus(expected: 0, recognized: 1), MatchStatus.unscheduled);
  });

  group('처방', () {
    Prescription prescription(List<PrescriptionItem> items) => Prescription(
      id: 1,
      startDate: DateTime(2026, 10, 1),
      days: 60,
      status: PrescriptionStatus.active,
      items: items,
    );

    test('처방 속 회차가 처방의 1회 알 수로 일정에 들어가고, 기록이 그 회차에 맞춰진다', () {
      final summary = summarizeDay(
        [a, c],
        [record(c, 13, 1, minute: 10)],
        prescriptions: [
          prescription(const [
            PrescriptionItem(
              medicationId: 3,
              dosePerTake: 2,
              times: [9 * 60, 13 * 60],
            ),
          ]),
        ],
      );
      expect(
        [
          for (final s in summary.slots)
            (s.medication.id, s.time, s.dose, s.taken),
        ],
        [
          (1, 8 * 60, 2, 0),
          (3, 9 * 60, 2, 0),
          (3, 13 * 60, 2, 1),
          (1, 20 * 60, 2, 0),
        ],
      );
      expect(summary.unscheduled, isEmpty);
    });

    test('같은 약이 같은 시간에 겹치면 하나만, 많은 쪽 개수로 둔다', () {
      final doses = dayDoses(
        [b],
        [
          prescription(const [
            PrescriptionItem(medicationId: 2, dosePerTake: 2, times: [8 * 60]),
          ]),
          prescription(const [
            PrescriptionItem(
              medicationId: 2,
              dosePerTake: 1,
              times: [8 * 60, 20 * 60],
            ),
          ]),
        ],
      );
      expect(doses, {
        2: {8 * 60: 2, 20 * 60: 1},
      });
    });

    test('지운 약의 처방 회차는 넣지 않는다', () {
      final summary = summarizeDay(
        [b],
        const [],
        prescriptions: [
          prescription(const [
            PrescriptionItem(medicationId: 99, dosePerTake: 1, times: [480]),
          ]),
        ],
      );
      expect([for (final s in summary.slots) s.medication.id], [2]);
    });
  });
}
