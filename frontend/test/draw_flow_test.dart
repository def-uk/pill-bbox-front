import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/cosmetic.dart';
import 'package:pillbbox/data/models/medication.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/intake_repository.dart';
import 'package:pillbbox/data/repositories/medication_repository.dart';
import 'package:pillbbox/data/repositories/prescription_repository.dart';
import 'package:pillbbox/data/services/fake_pill_detector.dart';
import 'package:pillbbox/data/services/pill_label_service.dart';
import 'package:pillbbox/main.dart';
import 'package:pillbbox/ui/common/cosmetic_widgets.dart';
import 'package:pillbbox/ui/common/creature_art.dart';
import 'package:pillbbox/ui/common/stage_widgets.dart';

import 'helpers.dart';

void main() {
  testWidgets('퇴치로 얻은 뽑기권으로 뽑고, 컬렉션에서 아이템과 펫을 장착하면 홈 캐릭터에 보인다', (tester) async {
    // 메모리 DB라 닫지 않는다. 위젯 테스트는 파일마다 하나만 둔다.
    final db = createTestDatabase();
    final photos = FakePhotoStorageService();
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 어제 하루짜리 처방을 사진으로 채워 퇴치했다: 뽑기권 1장, 펫 1마리.
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await tester.runAsync(() async {
      final medications = MedicationRepository(db, photos);
      final pill = await medications.save(
        categoryId: null,
        name: '항생제',
        dosePerTake: 1,
        times: const [],
        kind: MedicationKind.prescription,
      );
      await PrescriptionRepository(db, medications).save(
        startDate: yesterday,
        days: 1,
        items: [
          PrescriptionItem(
            medicationId: pill,
            dosePerTake: 1,
            times: const [8 * 60],
          ),
        ],
      );
      await IntakeRepository(
        db,
        photos,
        now: () => yesterday.add(const Duration(hours: 8)),
      ).addCameraIntake(photo: Uint8List(1), countsByMedication: {pill: 1});
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

    // 홈 → 뽑기
    await pumpUntilFound(tester, find.text('뽑기 · 1장'));
    await tester.tap(find.text('뽑기 · 1장'));
    await pumpUntilFound(tester, find.text('뽑기권 1장'));
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    await tester.tap(find.text('뽑기권 1장으로 뽑기'));
    await pumpUntilFound(tester, find.byType(CosmeticPreview));
    final drawn = tester
        .widget<CosmeticPreview>(find.byType(CosmeticPreview))
        .cosmetic;
    expect(find.text(drawn.name), findsOneWidget);
    expect(find.text('뽑기권 0장'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '뽑기권이 없어요'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(BackButton));

    // 홈 → 컬렉션: 뽑은 아이템과 펫을 장착
    await pumpUntilFound(tester, find.text('뽑기 · 0장'));
    await tester.tap(find.text('컬렉션'));
    await pumpUntilFound(tester, find.text('아이템을 누르면 장착하고, 다시 누르면 빼요'));
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(drawn.name),
      200,
      scrollable: list,
    );
    await tester.tap(find.text(drawn.name));
    await pumpUntilFound(
      tester,
      find.bySemanticsLabel(RegExp('^${drawn.name}, .*장착 중')),
    );
    await tester.scrollUntilVisible(
      find.text('처방 몬스터').first,
      200,
      scrollable: list,
    );
    await tester.tap(find.text('처방 몬스터').first);
    await pumpUntilFound(
      tester,
      find.bySemanticsLabel(RegExp('^처방 몬스터, 장착 중')),
    );
    await tester.scrollUntilVisible(find.text('퇴치 기록'), 200, scrollable: list);
    expect(find.textContaining('항생제'), findsNothing);
    await tester.tap(find.byType(BackButton));

    // 홈: 장착한 아이템과 펫
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(StageCard),
        matching: find.byWidgetPredicate(
          (w) => w is CharacterWithPet && w.pet != null,
        ),
      ),
    );
    final character = tester.widget<CharacterArt>(find.byType(CharacterArt));
    expect(
      drawn.slot == CosmeticSlot.skin
          ? character.skinId
          : character.accessoryId,
      drawn.id,
    );
    expect(
      tester.widget<CharacterWithPet>(find.byType(CharacterWithPet)).pet,
      isNotNull,
    );
  });
}
