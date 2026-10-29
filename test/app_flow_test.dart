import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('촬영 → 결과 확인 → 저장하면 홈에 오늘 기록이 보인다', (tester) async {
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
      ),
    );
    await pumpUntilFound(tester, find.text('아직 오늘 복용 기록이 없습니다'));

    await tester.tap(find.text('촬영'));
    await pumpUntilFound(tester, find.text('샘플 사진으로 계속'));

    await tester.tap(find.text('샘플 사진으로 계속'));
    await pumpUntilFound(tester, find.text('인식된 약'));
    expect(find.text('확인 필요'), findsOneWidget);
    expect(find.text('2정'), findsOneWidget);

    // 확인 필요인 C는 빼고 저장한다.
    await tester.tap(find.byTooltip('샘플약 C (분홍색 원형) 하나 빼기'));
    await tester.pump();
    await tester.tap(find.text('저장'));
    await pumpUntilFound(tester, find.text('복용 기록을 저장했습니다'));
    await pumpUntilFound(tester, find.text('오늘'));

    expect(find.text('샘플약 A (흰색 원형)'), findsOneWidget);
    expect(find.text('샘플약 B (노란색 타원형)'), findsOneWidget);
    expect(find.text('샘플약 C (분홍색 원형)'), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
