import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late MedicationRepository medications;
  late PrescriptionRepository prescriptions;
  var now = DateTime(2026, 11, 5, 9);

  setUp(() {
    db = createTestDatabase();
    medications = MedicationRepository(db, FakePhotoStorageService());
    prescriptions = PrescriptionRepository(db, medications, now: () => now);
  });
  tearDown(() => db.close());

  Future<int> medication(String name, {MedicationKind? kind}) =>
      medications.save(
        categoryId: null,
        name: name,
        dosePerTake: 1,
        times: const [],
        kind: kind,
      );

  test('처방을 저장하면 처방 속 약이 처방약이 되고, 회차 시간이 그대로 돌아온다', () async {
    final a = await medication('여드름약 A');
    final b = await medication('위장약 B', kind: MedicationKind.supplement);
    var notified = 0;
    prescriptions.addListener(() => notified++);

    final id = await prescriptions.save(
      startDate: DateTime(2026, 11, 5, 15, 30),
      days: 28,
      items: [
        PrescriptionItem(
          medicationId: a,
          dosePerTake: 1,
          times: const [8 * 60, 20 * 60],
        ),
        PrescriptionItem(
          medicationId: b,
          dosePerTake: 2,
          times: const [20 * 60],
        ),
      ],
    );

    final saved = (await prescriptions.getById(id))!;
    expect(saved.startDate, DateTime(2026, 11, 5));
    expect(saved.endDate, DateTime(2026, 12, 2));
    expect(saved.status, PrescriptionStatus.active);
    expect(
      [for (final i in saved.items) (i.medicationId, i.dosePerTake)],
      [(a, 1), (b, 2)],
    );
    expect(saved.items.first.times, [8 * 60, 20 * 60]);
    expect(saved.items.first.dailyAmount, 2);
    expect(saved.items.last.dailyAmount, 2);
    expect(
      {for (final m in await medications.getAll()) m.name: m.kind},
      {
        '여드름약 A': MedicationKind.prescription,
        '위장약 B': MedicationKind.prescription,
      },
    );
    expect(notified, 1);
  });

  test('처방 기간 안의 날에만 일정에 들어가고, 끝낸 처방은 빠진다', () async {
    final a = await medication('A');
    final id = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 3,
      items: [
        PrescriptionItem(medicationId: a, dosePerTake: 1, times: const [480]),
      ],
    );

    Future<List<int>> on(DateTime day) async => [
      for (final p in await prescriptions.scheduledOn(day)) p.id,
    ];
    expect(await on(DateTime(2026, 11, 4, 23, 59)), isEmpty);
    expect(await on(DateTime(2026, 11, 5)), [id]);
    expect(await on(DateTime(2026, 11, 7, 23, 59)), [id]);
    expect(await on(DateTime(2026, 11, 8)), isEmpty);

    final p = (await prescriptions.getById(id))!;
    expect(p.isOverOn(DateTime(2026, 11, 7)), isFalse);
    expect(p.isOverOn(DateTime(2026, 11, 8)), isTrue);
    final ended = Prescription(
      id: 0,
      startDate: DateTime(2026, 11, 5),
      days: 3,
      status: PrescriptionStatus.ended,
      items: [],
    );
    expect(ended.isScheduledOn(DateTime(2026, 11, 6)), isFalse);
  });

  test('고치면 처방 속 약을 통째로 바꾸고, 먼저 등록한 처방이 앞에 온다', () async {
    final a = await medication('A');
    final b = await medication('B');
    final first = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 7,
      items: [
        PrescriptionItem(medicationId: a, dosePerTake: 1, times: const [480]),
      ],
    );
    now = now.add(const Duration(minutes: 1));
    final second = await prescriptions.save(
      startDate: DateTime(2026, 11, 1),
      days: 30,
      items: [
        PrescriptionItem(medicationId: b, dosePerTake: 1, times: const [480]),
      ],
    );

    await prescriptions.save(
      id: first,
      startDate: DateTime(2026, 11, 6),
      days: 14,
      items: [
        PrescriptionItem(medicationId: b, dosePerTake: 3, times: const [720]),
      ],
    );

    final all = await prescriptions.getAll();
    expect([for (final p in all) p.id], [first, second]);
    expect((all.first.startDate, all.first.days), (DateTime(2026, 11, 6), 14));
    expect(
      [for (final i in all.first.items) (i.medicationId, i.dosePerTake)],
      [(b, 3)],
    );
  });

  test('처방을 지워도 약은 남고, 약을 지워 처방이 비면 처방도 지운다', () async {
    final a = await medication('A');
    final b = await medication('B');
    final both = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 7,
      items: [
        PrescriptionItem(medicationId: a, dosePerTake: 1, times: const [480]),
        PrescriptionItem(medicationId: b, dosePerTake: 1, times: const [480]),
      ],
    );
    final onlyA = await prescriptions.save(
      startDate: DateTime(2026, 11, 5),
      days: 7,
      items: [
        PrescriptionItem(medicationId: a, dosePerTake: 1, times: const [480]),
      ],
    );

    await medications.delete(a);
    final left = await prescriptions.getAll();
    expect([for (final p in left) p.id], [both]);
    expect([for (final i in left.single.items) i.medicationId], [b]);
    expect(await prescriptions.getById(onlyA), isNull);

    await prescriptions.delete(both);
    expect(await prescriptions.getAll(), isEmpty);
    expect([for (final m in await medications.getAll()) m.id], [b]);
  });
}
