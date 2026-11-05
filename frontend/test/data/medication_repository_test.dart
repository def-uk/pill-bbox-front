import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late FakePhotoStorageService photos;
  late MedicationRepository medications;

  setUp(() {
    db = createTestDatabase();
    photos = FakePhotoStorageService();
    medications = MedicationRepository(db, photos);
  });
  tearDown(() => db.close());

  test('약과 복용 시간을 저장하고, 고치면 시간을 통째로 바꾼다', () async {
    var notified = 0;
    medications.addListener(() => notified++);

    final id = await medications.save(
      categoryId: 9001,
      name: 'A',
      dosePerTake: 2,
      times: const [20 * 60, 8 * 60],
    );
    var saved = (await medications.getById(id))!;
    expect((saved.categoryId, saved.name, saved.dosePerTake), (9001, 'A', 2));
    expect(saved.times, [480, 1200]);

    await medications.save(
      id: id,
      categoryId: 9001,
      name: 'A',
      dosePerTake: 1,
      times: const [12 * 60],
    );
    saved = (await medications.getById(id))!;
    expect(saved.dosePerTake, 1);
    expect(saved.times, [720]);
    expect(await medications.getAll(), hasLength(1));
    expect(notified, 2);
  });

  test('같은 category_id로 두 번 등록할 수 없다', () async {
    await medications.save(
      categoryId: 9001,
      name: 'A',
      dosePerTake: 1,
      times: const [],
    );
    await expectLater(
      medications.save(
        categoryId: 9001,
        name: 'A2',
        dosePerTake: 1,
        times: const [],
      ),
      throwsA(anything),
    );
  });

  test('약을 지우면 일정·기록과 더 쓰이지 않는 사진을 함께 지운다', () async {
    final intakes = IntakeRepository(db, photos);
    final a = await medications.save(
      categoryId: null,
      name: 'A',
      dosePerTake: 1,
      times: const [480],
    );
    final b = await medications.save(
      categoryId: null,
      name: 'B',
      dosePerTake: 1,
      times: const [480],
    );
    await intakes.addCameraIntake(
      photo: Uint8List.fromList([1]),
      countsByMedication: {a: 1, b: 1},
    );
    await intakes.addCameraIntake(
      photo: Uint8List.fromList([2]),
      countsByMedication: {a: 1},
    );

    await medications.delete(a);

    expect([for (final m in await medications.getAll()) m.name], ['B']);
    final records = await intakes.recordsOn(DateTime.now());
    expect([for (final r in records) r.medicationId], [b]);
    expect(photos.photos.keys, [
      records.single.photoPath,
    ], reason: 'B 기록이 쓰는 사진만 남는다');
  });

  test('종류와 영양제 하루 권장량을 저장하고, 영양제가 아니면 권장량을 남기지 않는다', () async {
    final vitamin = await medications.save(
      categoryId: null,
      name: '비타민 D',
      dosePerTake: 1,
      times: const [],
      kind: MedicationKind.supplement,
      dailyLimit: 2,
    );
    final painkiller = await medications.save(
      categoryId: null,
      name: '진통제',
      dosePerTake: 1,
      times: const [],
      kind: MedicationKind.asNeeded,
      dailyLimit: 3,
    );
    final old = await medications.save(
      categoryId: null,
      name: '예전 약',
      dosePerTake: 1,
      times: const [],
    );

    Future<(MedicationKind?, int?)> kindOf(int id) async {
      final m = (await medications.getById(id))!;
      return (m.kind, m.dailyLimit);
    }

    expect(await kindOf(vitamin), (MedicationKind.supplement, 2));
    expect(await kindOf(painkiller), (MedicationKind.asNeeded, null));
    expect(await kindOf(old), (null, null));

    var notified = 0;
    medications.addListener(() => notified++);
    await medications.setKind([old, vitamin], MedicationKind.prescription);
    expect(await kindOf(old), (MedicationKind.prescription, null));
    expect(await kindOf(vitamin), (MedicationKind.prescription, null));
    await medications.setKind([old], MedicationKind.supplement, dailyLimit: 4);
    expect(await kindOf(old), (MedicationKind.supplement, 4));
    expect(notified, 2);
  });
}
