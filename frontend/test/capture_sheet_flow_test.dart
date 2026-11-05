import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('어느 탭에서든 기록하기를 누르면 샘플 사진을 골라 결과 확인으로 간다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final picker = SamplePhotoPickerService();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PillboxApp(
        database: db,
        photos: FakePhotoStorageService(),
        picker: picker,
        detector: FakePillDetector(delay: Duration.zero),
        labels: PillLabelService(),
      ),
    );
    await passAgeGate(tester);
    await pumpUntilFound(tester, find.text('싸우는 몬스터'));

    // 기록 탭으로 옮겨도 아래 바의 기록하기는 그대로 있다.
    await tester.tap(find.text('기록'));
    await pumpUntilFound(tester, find.byTooltip('기록하기'));
    expect(find.text('싸우는 몬스터'), findsNothing);

    await tester.tap(find.text('기록하기'));
    await pumpUntilFound(tester, find.text('샘플 사진'));
    expect(find.text('사진 찍기'), findsOneWidget);
    expect(find.text('사진 올리기'), findsOneWidget);
    await tester.tap(find.text('샘플 사진'));
    await pumpUntilFound(tester, find.text('인식된 약'));

    // 샘플은 사진 창을 열지 않는다.
    expect(picker.sources, isEmpty);
  });
}
