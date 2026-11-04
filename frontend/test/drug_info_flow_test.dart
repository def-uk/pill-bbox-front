import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('모델이 모르는 약을 식약처에서 찾아 등록하고 약 정보를 본다', (tester) async {
    final db = createTestDatabase();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PillboxApp(
        database: db,
        photos: FakePhotoStorageService(),
        picker: SamplePhotoPickerService(),
        detector: FakePillDetector(delay: Duration.zero),
        labels: PillLabelService(),
        drugInfo: fakeDrugInfo(),
      ),
    );
    await pumpUntilFound(tester, find.text('복용 시간 정하기'));
    await tester.tap(find.text('복용 시간 정하기'));
    await pumpUntilFound(tester, find.text('약 등록'));
    await tester.tap(find.text('약 등록'));
    await pumpUntilFound(tester, find.text('약을 고르세요'));

    // 약 고르기: 모델이 아는 약에 없으니 식약처에서 찾는다.
    await tester.tap(find.text('약을 고르세요'));
    await pumpUntilFound(tester, find.text('식약처에서 찾기'));
    await tester.enterText(find.byType(TextField), '두통약');
    await tester.pump();
    await tester.tap(find.text("식약처에서 '두통약' 찾기"));
    await pumpUntilFound(tester, find.text('두통약정500밀리그램'));
    expect(find.text('가나제약 · 원형 · 하양 · GN'), findsOneWidget);
    await tester.tap(find.text('두통약정500밀리그램'));
    await pumpUntilFound(
      tester,
      find.text('식약처 의약품 · 사진으로 인식되지 않아 직접 기록만 됩니다'),
    );
    await tester.tap(find.text('저장'));

    // 약 관리 → 다시 열어 약 정보
    await pumpUntilFound(tester, find.text('두통약정500밀리그램'));
    await tester.tap(find.text('두통약정500밀리그램'));
    await pumpUntilFound(tester, find.text('약 정보'));
    await tester.tap(find.text('약 정보'));
    await pumpUntilFound(tester, find.text('두통, 치통에 씁니다.'));
    expect(find.text('가나제약 · 일반의약품'), findsOneWidget);
    expect(find.text('8 × 8 × 3.2mm'), findsOneWidget);
    expect(find.text('실온에서 보관하십시오.'), findsOneWidget);
  });
}
