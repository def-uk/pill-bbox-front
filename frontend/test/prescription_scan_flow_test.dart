import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/photo_picker_service.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/data/services/prescription_scanner.dart';
import 'package:pillbbox/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('처방전을 찍으면 읽은 초안을 확인하고 등록하고, 새 몬스터가 나타난다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final picker = SamplePhotoPickerService();
    final labels = PillLabelService();
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
        labels: labels,
        prescriptionScanner: FakePrescriptionScanner(
          labels,
          delay: Duration.zero,
        ),
      ),
    );
    await passAgeGate(tester);

    // 약 관리 탭 → 처방 등록 → 처방전 찍기
    await pumpUntilFound(tester, find.text('약 관리'));
    await tester.tap(find.text('약 관리'));
    await pumpUntilFound(tester, find.text('등록한 약이 없습니다'));
    await tester.tap(find.text('처방 등록'));
    await pumpUntilFound(tester, find.text('처방전 찍기'));
    await tester.tap(find.text('처방전 찍기'));

    // 처방전 확인: 읽은 약 셋, 5일, 하루 세 번. 초안이라는 안내.
    await pumpUntilFound(tester, find.text('처방전 확인'));
    expect(picker.sources, [PhotoSource.camera]);
    expect(find.textContaining('초안이에요'), findsOneWidget);
    expect(find.text('샘플약 A (흰색)'), findsOneWidget);
    expect(find.text('샘플약 B (노란색 타원형)'), findsOneWidget);
    expect(find.text('샘플약 C (주황색 타원형)'), findsOneWidget);
    expect(find.text('1회 1정 · 하루 3회 (08:00, 12:30, 19:00)'), findsNWidgets(3));
    await tester.tap(find.text('확인하고 등록'));

    // 새 몬스터: 처방 5일이라 체력 5칸
    await pumpUntilFound(tester, find.text('새 몬스터'));
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.textContaining('샘플약'), findsNothing);
    await tester.tap(find.text('5일 동안 물리치기'));

    // 약 관리로 돌아와 처방이 보인다.
    await pumpUntilFound(tester, find.textContaining('부터 5일'));
  });
}
