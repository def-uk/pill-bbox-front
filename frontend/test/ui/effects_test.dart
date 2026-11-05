import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/cosmetic.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/data/repositories/settings_repository.dart';
import 'package:pillbbox/data/services/image_save_service.dart';
import 'package:pillbbox/ui/collection/draw_screen.dart';
import 'package:pillbbox/ui/collection/share_card.dart';
import 'package:pillbbox/ui/collection/share_card_screen.dart';
import 'package:pillbbox/ui/common/creature_art.dart';
import 'package:pillbbox/ui/common/stage_widgets.dart';
import 'package:pillbbox/ui/common/theme.dart';
import 'package:pillbbox/ui/reward/reward_screen.dart';
import 'package:pillbbox/utils/character.dart';
import 'package:pillbbox/utils/reward_calculator.dart';
import 'package:provider/provider.dart';

import '../helpers.dart';

MonsterState monster({
  required int dealt,
  DateTime? defeatedOn,
  int days = 7,
}) => MonsterState(
  prescription: Prescription(
    id: 1,
    startDate: DateTime(2026, 11, 1),
    days: days,
    status: PrescriptionStatus.active,
    items: const [],
  ),
  attackDays: [for (var d = 1; d <= dealt; d++) DateTime(2026, 11, d)],
  defeatedOn: defeatedOn,
);

class FakeImageSaver implements ImageSaveService {
  final saved = <(String, Uint8List)>[];

  @override
  Future<bool> savePng(String fileName, Uint8List bytes) async {
    saved.add((fileName, bytes));
    return true;
  }
}

void main() {
  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: appTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child,
      ),
    ),
  );

  final defeat = RewardOutcome(
    expBefore: 2,
    expAfter: 2 + defeatExp,
    monsters: [
      (
        before: monster(dealt: 6),
        after: monster(dealt: 7, defeatedOn: DateTime(2026, 11, 7)),
      ),
    ],
  );

  double hpBar(WidgetTester tester) => tester
      .widgetList<MeterBar>(find.byType(MeterBar))
      .firstWhere((b) => b.color == hpColor)
      .value;

  CharacterStage characterStage(WidgetTester tester) =>
      tester.widget<CharacterArt>(find.byType(CharacterArt).last).stage;

  testWidgets('보상 연출: 체력 막대가 줄고, 쓰러져 펫이 되고, 단계가 오르면 캐릭터가 바뀐다', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(RewardScreen(outcome: defeat, looks: const {1: null})),
    );
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(hpBar(tester), closeTo(1 / 7, 1e-9));
    expect(characterStage(tester), CharacterStage.egg);
    // 바뀐 숫자는 연출 중에도 글로 보인다.
    expect(find.text('체력 1 → 0 / 7'), findsOneWidget);

    await tester.pump(RewardScreen.duration ~/ 2);
    expect(hpBar(tester), 0);

    await tester.pumpAndSettle();
    expect(find.text('건너뛰기'), findsNothing);
    expect(characterStage(tester), CharacterStage.baby);
    expect(find.text('아기(으)로 자랐어요!'), findsOneWidget);
    expect(find.text('펫이 생겼어요'), findsOneWidget);
    expect(find.text('경험치 +3 · 뽑기권 +1'), findsOneWidget);
  });

  testWidgets('보상 연출은 건너뛰기로 끝까지 넘긴다', (tester) async {
    await tester.pumpWidget(
      app(RewardScreen(outcome: defeat, looks: const {1: null})),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    expect(find.text('건너뛰기'), findsNothing);
    expect(hpBar(tester), 0);
    await tester.pump(const Duration(seconds: 1));
    expect(characterStage(tester), CharacterStage.baby);
  });

  testWidgets('애니메이션을 줄였으면 끝난 모습만 보여 준다', (tester) async {
    await tester.pumpWidget(
      app(
        RewardScreen(outcome: defeat, looks: const {1: null}),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('건너뛰기'), findsNothing);
    expect(hpBar(tester), 0);
    expect(characterStage(tester), CharacterStage.baby);
  });

  testWidgets('뽑기 연출: 캡슐이 열리면 아이템이 나오고, 누르면 끝까지 넘긴다', (tester) async {
    final unique = cosmetics.firstWhere((c) => c.grade == Grade.unique);
    await tester.pumpWidget(
      app(Scaffold(body: DrawReveal(cosmetic: unique, count: 1))),
    );
    expect(find.text('눌러서 건너뛰기'), findsOneWidget);
    expect(find.byType(CharacterArt), findsNothing);

    await tester.tap(find.byType(DrawReveal));
    await tester.pump();
    expect(find.text('눌러서 건너뛰기'), findsNothing);
    expect(find.byType(CharacterArt), findsOneWidget);
    expect(find.text(unique.name), findsOneWidget);
  });

  testWidgets('공유 카드는 캐릭터만 담아 PNG로 저장한다', (tester) async {
    final saver = FakeImageSaver();
    final db = createTestDatabase();
    final settings = SettingsRepository(db);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ImageSaveService>.value(value: saver),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: app(
          ShareCardScreen(
            now: () => DateTime(2026, 11, 20),
            data: ShareCardData(
              exp: 8,
              skin: Cosmetic.byId('skin_mint'),
              accessory: Cosmetic.byId('acc_cap'),
              pet: (1, (color: '주황', shape: '길쭉')),
            ),
          ),
        ),
      ),
    );
    expect(find.text('내 캐릭터 · 어린이'), findsOneWidget);
    expect(find.text('민트 스킨 · 야구 모자 · 펫 · 주황 길쭉 몬스터'), findsOneWidget);
    // 카드 안에는 경험치 숫자나 날짜가 없다.
    final cardTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ShareCard),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data!)
        .join(' ');
    expect(cardTexts, isNot(contains(RegExp(r'\d'))));

    await tester.tap(find.text('이미지로 저장'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(saver.saved, hasLength(1));
    final (name, bytes) = saver.saved.single;
    expect(name, '알약몬-캐릭터-2026-11-20.png');
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(find.text('이미지로 저장했어요'), findsOneWidget);
    // 4주 검증 지표에 쓰는 저장 횟수.
    expect(await tester.runAsync(settings.shareSaves), 1);
  });
}
