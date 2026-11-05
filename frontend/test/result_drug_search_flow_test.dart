import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('결과 확인에서 식약처 약을 찾아 효능·주의·생김새를 보고 그 약으로 기록한다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
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
    await passAgeGate(tester);

    await pumpUntilFound(tester, find.text('기록하기'));
    await tester.tap(find.text('기록하기'));
    await pumpUntilFound(tester, find.text('사진 올리기'));
    await tester.tap(find.text('사진 올리기'));
    await pumpUntilFound(tester, find.text('인식된 약'));

    await tester.ensureVisible(find.text('약 추가'));
    await tester.pump();
    await tester.tap(find.text('약 추가'));
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).last, '두통약');
    await tester.pump();
    await tester.tap(find.text("식약처에서 '두통약' 찾기"));
    await pumpUntilFound(tester, find.text('두통약정500밀리그램'));
    await tester.tap(find.text('두통약정500밀리그램'));

    // 고르기 전에 효능과 생김새를 본다.
    await pumpUntilFound(tester, find.text('두통, 치통에 씁니다.'));
    expect(find.text('효능'), findsOneWidget);
    expect(find.text('생김새'), findsOneWidget);
    await tester.tap(find.text('이 약으로 기록'));

    // 결과 확인에 처음 기록하는 약으로 들어온다.
    await pumpUntilFound(tester, find.text('두통약정500밀리그램'));
    expect(find.text('이 약으로 기록'), findsNothing);
  });
}
