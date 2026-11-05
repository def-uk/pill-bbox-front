import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('어제 사진 기록으로 깎인 몬스터를 홈에서 보고, 처방을 끝내면 깎은 체력만큼 경험치를 받는다', (
    tester,
  ) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final photos = FakePhotoStorageService();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 어제 시작한 28일 처방(08:00 1알)과 어제 08:10의 사진 기록.
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await tester.runAsync(() async {
      final medications = MedicationRepository(db, photos);
      final acne = await medications.save(
        categoryId: null,
        name: '여드름약',
        dosePerTake: 1,
        times: const [],
      );
      await medications.addAppearance(
        acne,
        const Appearance(l: 75, a: 24, b: 79, elongation: 2.0),
      );
      await PrescriptionRepository(db, medications).save(
        startDate: yesterday,
        days: 28,
        items: [
          PrescriptionItem(
            medicationId: acne,
            dosePerTake: 1,
            times: const [8 * 60],
          ),
        ],
      );
      await IntakeRepository(
        db,
        photos,
        now: () => yesterday.add(const Duration(hours: 8, minutes: 10)),
      ).addCameraIntake(photo: Uint8List(1), countsByMedication: {acne: 1});
    });

    await tester.pumpWidget(
      PillboxApp(
        database: db,
        photos: photos,
        picker: SamplePhotoPickerService(),
        detector: FakePillDetector(delay: Duration.zero),
        labels: PillLabelService(),
      ),
    );

    // 홈: 약 이름 없이 색·모양으로 지은 몬스터와 체력
    await pumpUntilFound(tester, find.text('주황 길쭉 몬스터'));
    expect(find.text('체력 27 / 28'), findsOneWidget);
    expect(find.text('경험치 0'), findsOneWidget);

    // 몬스터 상세: 어제 깎았고, 처방 끝내기
    await tester.tap(find.text('주황 길쭉 몬스터'));
    await pumpUntilFound(tester, find.text('지난 기록'));
    expect(find.text('27 / 28'), findsOneWidget);
    expect(find.text('체력 -1'), findsOneWidget);
    expect(find.textContaining('의사·약사의 안내를 따르세요'), findsOneWidget);
    expect(find.textContaining('여드름약'), findsNothing);

    await tester.tap(find.text('처방 끝내기'));
    await pumpUntilFound(tester, find.textContaining('깎은 체력 1만큼'));
    await tester.tap(find.text('처방 끝내기').last);
    await pumpUntilFound(tester, find.text('처방을 끝내 물러났어요'));
    expect(find.text('처방 끝내기'), findsNothing);

    // 홈: 몬스터는 물러나고 경험치 1
    await tester.tap(find.byType(BackButton));
    await pumpUntilFound(tester, find.text('경험치 1'));
    expect(find.text('주황 길쭉 몬스터'), findsNothing);
  });
}
