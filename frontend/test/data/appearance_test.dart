import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/appearance.dart';

void main() {
  Appearance look({double l = 60, double elongation = 1.5}) =>
      Appearance(l: l, a: 10, b: 20, elongation: elongation);

  test('같은 물체는 가깝고, 색이 많이 다르면 멀다', () {
    expect(look().distanceTo(look()), 0);
    expect(
      look().distanceTo(look(l: 63)),
      lessThan(Appearance.similarDistance),
    );
    expect(
      look().distanceTo(look(l: 90)),
      greaterThan(Appearance.similarDistance),
    );
  });

  test('길쭉함은 비율로 비교한다', () {
    // 웹에서 같은 막대가 다시 압축되며 7.56과 8.07로 잡혔다.
    expect(
      look(elongation: 7.56).distanceTo(look(elongation: 8.07)),
      lessThan(1),
    );
    // 둥근 알약과 타원형 알약은 다르다.
    expect(
      look(elongation: 1.0).distanceTo(look(elongation: 2.0)),
      greaterThan(Appearance.similarDistance),
    );
  });
}
