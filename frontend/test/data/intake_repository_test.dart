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
  late DateTime now;

  setUp(() {
    db = createTestDatabase();
    photos = FakePhotoStorageService();
    medications = MedicationRepository(db, photos);
    now = DateTime(2026, 10, 30, 9, 15);
  });
  tearDown(() => db.close());

  IntakeRepository repository() => IntakeRepository(db, photos, now: () => now);

  Future<int> addMedication(String name) => medications.save(
    categoryId: null,
    name: name,
    dosePerTake: 1,
    times: const [],
  );

  test('사진 한 장의 기록을 같은 시각으로 저장하고 날짜별로 읽는다', () async {
    final intakes = repository();
    var notified = 0;
    intakes.addListener(() => notified++);
    final a = await addMedication('A');
    final b = await addMedication('B');

    await intakes.addCameraIntake(
      photo: Uint8List.fromList([1, 2, 3]),
      countsByMedication: {a: 2, b: 0},
    );

    final records = await intakes.recordsOn(DateTime(2026, 10, 30));
    expect(records, hasLength(1), reason: '0개인 약은 건너뛴다');
    expect(records.single.medicationId, a);
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

  test('직접 기록은 사진 없이 저장한다', () async {
    final intakes = repository();
    final a = await addMedication('A');

    await intakes.addManualIntake(medicationId: a, count: 1);

    final record = (await intakes.recordsOn(now)).single;
    expect(record.source, IntakeSource.manual);
    expect(record.photoPath, isNull);
  });

  test('기록이 있는 날짜를 최근 날짜부터 돌려준다', () async {
    final intakes = repository();
    final a = await addMedication('A');
    for (final day in [
      DateTime(2026, 10, 28, 23, 59),
      DateTime(2026, 10, 30, 0, 1),
      DateTime(2026, 10, 30, 8),
    ]) {
      now = day;
      await intakes.addManualIntake(medicationId: a, count: 1);
    }

    expect(await intakes.recordedDays(), [
      DateTime(2026, 10, 30),
      DateTime(2026, 10, 28),
    ]);
  });

  test('기록을 지우면 다른 기록이 쓰지 않는 사진만 지운다', () async {
    final intakes = repository();
    final a = await addMedication('A');
    final b = await addMedication('B');
    await intakes.addCameraIntake(
      photo: Uint8List.fromList([1]),
      countsByMedication: {a: 1, b: 1},
    );
    final [recordA, recordB] = await intakes.recordsOn(now);

    await intakes.delete(recordA.id);
    expect(photos.photos, hasLength(1), reason: 'B 기록이 아직 같은 사진을 쓴다');

    await intakes.delete(recordB.id);
    expect(photos.photos, isEmpty);
    expect(await intakes.recordsOn(now), isEmpty);
  });
}
