import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('처음 열면 나이를 묻고, 만 14세 미만이면 쓸 수 없고, 확인하면 다음부터 묻지 않는다', (
    tester,
  ) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget app() => PillboxApp(
      database: db,
      photos: FakePhotoStorageService(),
      picker: SamplePhotoPickerService(),
      detector: FakePillDetector(delay: Duration.zero),
      labels: PillLabelService(),
    );

    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('만 14세 이상인가요?'));
    expect(find.textContaining('의약품 96종'), findsOneWidget);
    expect(find.textContaining('의사·약사의 안내를 따르세요'), findsOneWidget);

    await tester.tap(find.text('아니요'));
    await pumpUntilFound(tester, find.text('알약몬은 만 14세 이상만 쓸 수 있어요'));
    expect(find.text('기록하기'), findsNothing);
    await tester.tap(find.text('처음으로'));
    await pumpUntilFound(tester, find.text('만 14세 이상인가요?'));

    await tester.tap(find.text('네, 만 14세 이상이에요'));
    await pumpUntilFound(tester, find.text('오늘 기록이 없습니다'));

    // 앱을 다시 열어도 묻지 않는다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await pumpUntilFound(tester, find.text('오늘 기록이 없습니다'));
    expect(find.text('만 14세 이상인가요?'), findsNothing);

    // 더 보기 → 앱 안내
    await tester.tap(find.byTooltip('더 보기'));
    await pumpUntilFound(tester, find.text('앱 안내'));
    await tester.tap(find.text('앱 안내'));
    await pumpUntilFound(tester, find.textContaining('의약품 96종'));
    await tester.tap(find.byType(BackButton));

    // 더 보기 → 테스트 지표
    await pumpUntilFound(tester, find.byTooltip('더 보기'));
    await tester.tap(find.byTooltip('더 보기'));
    await pumpUntilFound(tester, find.text('테스트 지표'));
    await tester.tap(find.text('테스트 지표'));
    await pumpUntilFound(tester, find.text('아직 기록이 없어요'));
    expect(find.text('공유 카드 저장'), findsOneWidget);
    expect(find.text('0번'), findsOneWidget);
  });
}
