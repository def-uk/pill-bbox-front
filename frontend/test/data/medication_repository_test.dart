import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
}
