import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('처방을 등록하면 회차가 홈의 오늘 일정에 나오고, 결과 확인에서 예정과 비교된다', (tester) async {
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
      ),
    );
    await pumpUntilFound(tester, find.text('복용 시간 정하기'));
    await tester.tap(find.text('복용 시간 정하기'));
    await pumpUntilFound(tester, find.text('처방 등록'));
    await tester.tap(find.text('처방 등록'));
    await pumpUntilFound(tester, find.text('처방받은 약'));

    // 약을 넣기 전에는 저장할 수 없다.
    FilledButton saveButton() =>
        tester.widget(find.widgetWithText(FilledButton, '저장'));
    expect(saveButton().onPressed, isNull);

    // 샘플약 A: 1회 2정, 08:00
    await tester.tap(find.text('약 추가'));
    await pumpUntilFound(tester, find.text('샘플약 A (흰색)'));
    await tester.tap(find.text('샘플약 A (흰색)'));
    await pumpUntilFound(tester, find.text('1회 알 수'));
    await tester.tap(find.byTooltip('1정 늘리기'));
    await tester.tap(find.text('시간 추가'));
    await pumpUntilFound(tester, find.text('확인'));
    await tester.tap(find.text('확인').last);
    await pumpUntilFound(tester, find.text('복용 시간 · 하루 1회'));
    await tester.tap(find.widgetWithText(FilledButton, '확인'));
    await pumpUntilFound(tester, find.text('1회 2정 · 하루 1회 (08:00)'));

    // 목록에 없는 약은 이름을 그대로 넣는다. 회차 시간은 앞 줄과 같게 채워진다.
    await tester.tap(find.text('약 추가'));
    await pumpUntilFound(tester, find.text('약 고르기'));
    await tester.enterText(find.byType(TextField), '위장약');
    await tester.pump();
    await tester.tap(find.text("'위장약' 직접 입력"));
    await pumpUntilFound(tester, find.text('복용 시간 · 하루 1회'));
    await tester.tap(find.widgetWithText(FilledButton, '확인'));
    await pumpUntilFound(tester, find.text('1회 1정 · 하루 1회 (08:00)'));

    await tester.tap(find.text('28일'));
    await tester.pump();
    await tester.tap(find.text('저장'));

    // 약 관리: 처방 한 줄과 처방약이 된 두 약
    await pumpUntilFound(tester, find.text('샘플약 A (흰색), 위장약'));
    expect(find.textContaining('부터 28일'), findsOneWidget);
    expect(find.text('처방약 · 1회 2정'), findsOneWidget);
    expect(find.text('처방약 · 1회 1정 · 직접 기록만'), findsOneWidget);
    await tester.tap(find.byType(BackButton));

    // 홈: 08:00에 두 약이 처방의 1회 알 수로
    await pumpUntilFound(tester, find.text('08:00'));
    expect(find.text('샘플약 A (흰색)'), findsOneWidget);
    expect(find.text('1회 2정'), findsOneWidget);
    expect(find.text('위장약'), findsOneWidget);
    expect(find.text('1회 1정'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);

    // 결과 확인: A는 예정대로, 위장약은 사진에 없어 예정보다 적다
    await tester.tap(find.text('기록하기'));
    await pumpUntilFound(tester, find.text('사진 올리기'));
    await tester.tap(find.text('사진 올리기'));
    await pumpUntilFound(tester, find.text('인식된 약'));
    expect(find.text('✓ 예정대로', findRichText: true), findsOneWidget);
    expect(find.text('예정 1정 중 0정', findRichText: true), findsOneWidget);
  });
}
