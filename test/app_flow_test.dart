import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('약을 등록하면 홈에 예정이 보이고, 촬영해 저장하면 완료로 바뀐다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트에서 닫으면 sqflite가 끝나지 않는다.
    final db = createTestDatabase();
    // 휴대폰 화면 크기 (360×800).
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PillboxApp(
        database: db,
        photos: FakePhotoStorageService(),
        camera: NoCameraService(),
        detector: FakePillDetector(delay: Duration.zero),
        labels: PillLabelService(),
      ),
    );
    await pumpUntilFound(tester, find.text('복용할 약을 먼저 등록해 주세요'));

    // 약 등록: 샘플약 A, 1회 2정, 08:00
    await tester.tap(find.text('약 등록'));
    await pumpUntilFound(tester, find.text('약을 고르세요'));
    await tester.tap(find.text('약을 고르세요'));
    await pumpUntilFound(tester, find.text('샘플약 A (흰색 원형)'));
    await tester.tap(find.text('샘플약 A (흰색 원형)'));
    await pumpUntilFound(tester, find.text('사진으로 인식되는 약'));
    await tester.tap(find.byTooltip('1정 늘리기'));
    await tester.tap(find.text('시간 추가'));
    await pumpUntilFound(tester, find.text('확인'));
    await tester.tap(find.text('확인'));
    await pumpUntilFound(tester, find.text('08:00'));
    await tester.tap(find.text('저장'));

    // 홈: 08:00에 A 2정 예정
    await pumpUntilFound(tester, find.text('예정'));
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('샘플약 A (흰색 원형)'), findsOneWidget);
    expect(find.text('1회 2정'), findsOneWidget);

    // 촬영 → 결과 확인: A는 예정대로, B·C는 등록하지 않은 약
    await tester.tap(find.text('촬영'));
    await pumpUntilFound(tester, find.text('샘플 사진으로 계속'));
    await tester.tap(find.text('샘플 사진으로 계속'));
    await pumpUntilFound(tester, find.text('인식된 약'));
    expect(find.text('✓ 예정대로', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('등록하지 않은 약 · 눌러서 바꾸기', findRichText: true),
      findsNWidgets(2),
    );

    await tester.tap(find.text('저장'));
    await pumpUntilFound(tester, find.text('복용 기록을 저장했습니다'));

    // 홈: A 완료
    await pumpUntilFound(tester, find.text('완료'));
    expect(find.text('예정'), findsNothing);
  });
}
