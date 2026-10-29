import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/intake_record.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/database_service.dart';

import '../helpers.dart';

void main() {
  late DatabaseService db;
  late FakePhotoStorageService photos;
  late MedicationRepository medications;
  var now = DateTime(2026, 10, 30, 9, 15);

  setUp(() {
    db = createTestDatabase();
    photos = FakePhotoStorageService();
    medications = MedicationRepository(db);
  });
  tearDown(() => db.close());

  IntakeRepository repository() => IntakeRepository(db, photos, now: () => now);

  test('findOrCreateByCategory는 같은 약을 두 번 만들지 않는다', () async {
    final a = await medications.findOrCreateByCategory(
      categoryId: 1,
      name: 'A',
    );
    final again = await medications.findOrCreateByCategory(
      categoryId: 1,
      name: 'A',
    );
    expect(again.id, a.id);
    expect(await medications.getAll(), hasLength(1));
  });

  test('사진 한 장의 기록을 같은 시각으로 저장하고 날짜별로 읽는다', () async {
    final intakes = repository();
    var notified = 0;
    intakes.addListener(() => notified++);
    final a = await medications.findOrCreateByCategory(
      categoryId: 1,
      name: 'A',
    );
    final b = await medications.findOrCreateByCategory(
      categoryId: 2,
      name: 'B',
    );

    await intakes.addCameraIntake(
      photo: Uint8List.fromList([1, 2, 3]),
      countsByMedication: {a.id: 2, b.id: 0},
    );

    final records = await intakes.recordsOn(DateTime(2026, 10, 30));
    expect(records, hasLength(1), reason: '0개인 약은 건너뛴다');
    expect(records.single.medicationId, a.id);
    expect(records.single.count, 2);
    expect(records.single.takenAt, now);
    expect(records.single.source, IntakeSource.camera);
    expect(photos.photos.keys, [records.single.photoPath]);
    expect(notified, 1);

    expect(await intakes.recordsOn(DateTime(2026, 10, 29)), isEmpty);
    expect(await intakes.recordsOn(DateTime(2026, 10, 31)), isEmpty);
  });

  test('저장에 실패하면 사진을 지운다', () async {
    await expectLater(
      repository().addCameraIntake(
        photo: Uint8List.fromList([1]),
        countsByMedication: {999: 1},
      ),
      throwsA(anything),
      reason: '없는 약 id는 외래 키에 걸린다',
    );
    expect(photos.photos, isEmpty);
  });
}
