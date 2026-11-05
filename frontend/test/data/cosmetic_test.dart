import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/data/models/cosmetic.dart';

void main() {
  test('스킨·액세서리 12종, 등급 확률을 더하면 100%', () {
    expect(cosmetics, hasLength(12));
    expect({for (final c in cosmetics) c.id}, hasLength(12));
    expect(cosmetics.where((c) => c.slot == CosmeticSlot.skin), hasLength(6));
    expect(Grade.values.fold(0, (sum, g) => sum + g.percent), 100);
    expect(
      cosmetics.fold(0.0, (sum, c) => sum + c.percent),
      closeTo(100, 1e-9),
    );
  });

  test('뽑기 결과가 공개한 확률대로 나온다', () {
    final random = Random(42);
    const draws = 200000;
    final byGrade = {for (final g in Grade.values) g: 0};
    final byItem = {for (final c in cosmetics) c.id: 0};
    for (var i = 0; i < draws; i++) {
      final c = drawCosmetic(random);
      byGrade[c.grade] = byGrade[c.grade]! + 1;
      byItem[c.id] = byItem[c.id]! + 1;
    }
    for (final g in Grade.values) {
      expect(
        byGrade[g]! / draws * 100,
        closeTo(g.percent, 0.5),
        reason: g.label,
      );
    }
    for (final c in cosmetics) {
      expect(
        byItem[c.id]! / draws * 100,
        closeTo(c.percent, 0.4),
        reason: c.name,
      );
    }
  });
}
