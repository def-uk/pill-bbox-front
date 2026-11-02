import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('약을 등록하지 않아도 사진을 올려 저장하면 오늘 기록에 남는다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트에서 닫으면 sqflite가 끝나지 않는다.
    // 닫지 않은 DB가 다음 테스트로 이어지지 않도록 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PillboxApp(
        database: db,
        photos: FakePhotoStorageService(),
        picker: NoPhotoPickerService(),
        detector: FakePillDetector(delay: Duration.zero),
        labels: PillLabelService(),
      ),
    );
    await pumpUntilFound(tester, find.textContaining('오늘 기록이 없습니다'));

    await tester.tap(find.text('사진 올리기'));
    await pumpUntilFound(tester, find.text('샘플 사진으로 해 보기'));
    await tester.tap(find.text('샘플 사진으로 해 보기'));
    await pumpUntilFound(tester, find.text('인식된 약'));
    expect(
      find.textContaining('처음 기록하는 약', findRichText: true),
      findsNWidgets(3),
    );

    await tester.tap(find.text('저장'));
    await pumpUntilFound(tester, find.text('복용 기록을 저장했습니다'));

    await pumpUntilFound(tester, find.text('오늘 기록'));
    expect(find.text('샘플약 A (흰색 원형)'), findsOneWidget);
    expect(find.text('2정'), findsOneWidget);
  });
}
