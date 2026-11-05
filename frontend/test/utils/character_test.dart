import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/utils/character.dart';

void main() {
  test('누적 경험치 3·7·14·30에서 단계가 오른다', () {
    expect(
      {
        for (final exp in [0, 2, 3, 6, 7, 13, 14, 29, 30, 120])
          exp: CharacterStage.of(exp),
      },
      {
        0: CharacterStage.egg,
        2: CharacterStage.egg,
        3: CharacterStage.baby,
        6: CharacterStage.baby,
        7: CharacterStage.child,
        13: CharacterStage.child,
        14: CharacterStage.grown,
        29: CharacterStage.grown,
        30: CharacterStage.complete,
        120: CharacterStage.complete,
      },
    );
  });

  test('다음 단계까지 남은 경험치와 막대 비율', () {
    expect((Growth(0).toNext, Growth(0).progress), (3, 0.0));
    expect((Growth(5).toNext, Growth(5).progress), (2, 0.5));
    expect((Growth(10).toNext, Growth(10).progress), (4, 3 / 7));
    expect((Growth(31).toNext, Growth(31).progress), (0, 1.0));
    expect(CharacterStage.complete.next, isNull);
  });
}
