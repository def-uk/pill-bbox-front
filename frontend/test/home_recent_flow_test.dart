import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('오늘 기록이 없으면 홈에 최근 기록만 보이고, 찍는 법은 기록하기 시트에 있다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final photos = FakePhotoStorageService();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 어제 직접 기록한 약 하나.
    await tester.runAsync(() async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 8, 12);
      final id = await MedicationRepository(db, photos).save(
        categoryId: null,
        name: '어제 먹은 약',
        dosePerTake: 1,
        times: const [],
        kind: MedicationKind.supplement,
        dailyLimit: 2,
      );
      await IntakeRepository(
        db,
        photos,
        now: () => yesterday,
      ).addManualIntake(medicationId: id, count: 2);
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
    await passAgeGate(tester);
    await pumpUntilFound(tester, find.text('오늘 기록이 없습니다'));

    await tester.ensureVisible(find.text('최근 기록'));
    await tester.pump();
    expect(find.text('어제 먹은 약'), findsOneWidget);
    expect(find.text('2정'), findsOneWidget);
    expect(find.text('복용 시간 정하기'), findsNothing);
    expect(find.text('이렇게 찍어 주세요'), findsNothing);

    // 전체 보기는 기록 탭으로 간다.
    await tester.tap(find.text('전체 보기'));
    await pumpUntilFound(tester, find.byTooltip('기록하기'));
    expect(find.text('최근 기록'), findsNothing);

    await tester.tap(find.text('기록하기'));
    await pumpUntilFound(tester, find.text('이렇게 찍어 주세요'));
    expect(find.text('단색 배경 위에 놓기'), findsOneWidget);
  });
}
