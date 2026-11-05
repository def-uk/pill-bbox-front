import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/prescription.dart';
import 'package:pillbbox/ui/common/creature_art.dart';
import 'package:pillbbox/ui/common/stage_widgets.dart';
import 'package:pillbbox/ui/common/theme.dart';
import 'package:pillbbox/utils/character.dart';
import 'package:pillbbox/utils/reward_calculator.dart';

MonsterState monster(int id, {int dealt = 0}) => MonsterState(
  prescription: Prescription(
    id: id,
    startDate: DateTime(2026, 11, 1),
    days: 28,
    status: PrescriptionStatus.active,
    items: const [],
  ),
  attackDays: [for (var d = 1; d <= dealt; d++) DateTime(2026, 11, d)],
);

void main() {
  Future<void> pumpStage(
    WidgetTester tester,
    int exp,
    List<MonsterState> monsters,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: StageCard(
          growth: Growth(exp),
          monsters: monsters,
          looks: const {1: (color: '주황', shape: '길쭉'), 2: null},
          today: DateTime(2026, 11, 3),
          onTapMonster: (_) {},
        ),
      ),
    ),
  );

  testWidgets('경험치 3·7·14·30에서 무대의 캐릭터 그림이 바뀐다', (tester) async {
    CharacterStage shown() =>
        tester.widget<CharacterArt>(find.byType(CharacterArt)).stage;
    final seen = <CharacterStage>[];
    for (final exp in [2, 3, 7, 14, 30]) {
      await pumpStage(tester, exp, const []);
      seen.add(shown());
    }
    expect(seen, CharacterStage.values);
    expect(find.text('다 자랐어요'), findsOneWidget);
  });

  testWidgets('처방 둘이면 몬스터 둘이 각자 체력으로 보인다', (tester) async {
    await pumpStage(tester, 5, [monster(1, dealt: 3), monster(2)]);
    expect(find.byType(MonsterArt), findsNWidgets(2));
    expect(find.text('주황 길쭉 몬스터'), findsOneWidget);
    expect(find.text('처방 몬스터'), findsOneWidget);
    expect(find.text('체력 25 / 28'), findsOneWidget);
    expect(find.text('체력 28 / 28'), findsOneWidget);
    // 오늘(11월 3일) 깎은 몬스터만 표시.
    expect(find.text('오늘 -1'), findsOneWidget);
    expect(find.text('아기'), findsOneWidget);
    expect(find.text('어린이까지 2'), findsOneWidget);
    // 캡슐·길쭉한 약은 캡슐 몬스터.
    expect(
      tester.widgetList<MonsterArt>(find.byType(MonsterArt)).first.body,
      MonsterBody.capsule,
    );
  });

  test('색 이름을 몸 색으로, 모르는 색은 기본 몬스터 색으로', () {
    expect(monsterColor('주황'), isNot(CreatureColors.unknownMonster));
    expect(monsterColor('하양/분홍'), monsterColor('하양'));
    expect(monsterColor('무지개'), CreatureColors.unknownMonster);
    expect(monsterColor(null), CreatureColors.unknownMonster);
  });
}
