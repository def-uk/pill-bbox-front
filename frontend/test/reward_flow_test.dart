import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';
import 'package:pillbbox/ui/common/creature_art.dart';
import 'package:pillbbox/utils/time_format.dart';

import 'helpers.dart';

void main() {
  testWidgets('사진을 저장하면 보상 결과에 몬스터 체력과 경험치 변화가 나오고, 홈에 돌아오면 값이 바뀌어 있다', (
    tester,
  ) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final photos = FakePhotoStorageService();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 가짜 탐지기는 샘플약 A 2알, B 1알, C 1알을 찾는다.
    // 지금 시각을 회차로 둬서 사진 하나로 오늘 회차가 모두 찬다.
    final now = DateTime.now();
    final time = minuteOfDay(now);
    await tester.runAsync(() async {
      final medications = MedicationRepository(db, photos);
      final prescriptions = PrescriptionRepository(db, medications);
      Future<int> register(int categoryId, String name, MedicationKind kind) =>
          medications.save(
            categoryId: categoryId,
            name: name,
            dosePerTake: 1,
            times: kind == MedicationKind.supplement ? [time] : const [],
            kind: kind,
            dailyLimit: 1,
          );
      final a = await register(9001, '샘플약 A (흰색)', MedicationKind.prescription);
      await register(9002, '샘플약 B (노란색 타원형)', MedicationKind.supplement);
      final c = await register(
        9003,
        '샘플약 C (주황색 타원형)',
        MedicationKind.prescription,
      );
      for (final (id, dose) in [(a, 2), (c, 1)]) {
        await prescriptions.save(
          startDate: now,
          days: 7,
          items: [
            PrescriptionItem(
              medicationId: id,
              dosePerTake: dose,
              times: [time],
            ),
          ],
        );
      }
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

    // 홈 무대: 알 단계 캐릭터와 몬스터 둘
    await pumpUntilFound(tester, find.text('체력 7 / 7'));
    expect(find.text('체력 7 / 7'), findsNWidgets(2));
    expect(find.byType(MonsterArt), findsNWidgets(2));
    expect(find.text('경험치 0'), findsOneWidget);

    await tester.tap(find.text('기록하기'));
    await pumpUntilFound(tester, find.text('사진 올리기'));
    await tester.tap(find.text('사진 올리기'));
    await pumpUntilFound(tester, find.text('인식된 약'));
    await tester.tap(find.text('저장'));

    // 보상 결과
    await pumpUntilFound(tester, find.text('보상'));
    expect(find.text('체력 7 → 6 / 7'), findsNWidgets(2));
    expect(find.text('경험치 +1'), findsOneWidget);
    expect(find.text('경험치 0 → 1'), findsOneWidget);
    expect(find.textContaining('샘플약'), findsNothing);
    await tester.tap(find.text('확인'));

    // 홈: 값이 바뀌어 있다
    await pumpUntilFound(tester, find.text('체력 6 / 7'));
    expect(find.text('체력 6 / 7'), findsNWidgets(2));
    expect(find.text('오늘 -1'), findsNWidgets(2));
    expect(find.text('경험치 1'), findsOneWidget);
  });
}
