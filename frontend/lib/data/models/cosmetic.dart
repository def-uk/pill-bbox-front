import 'dart:math';

/// 뽑기 등급. 등급별 확률은 화면에 그대로 공개한다 (docs/MVP.md 7.1).
enum Grade {
  common('일반', 70),
  rare('희귀', 25),
  unique('유니크', 5);

  const Grade(this.label, this.percent);

  final String label;

  /// 이 등급이 나올 확률(%).
  final int percent;
}

enum CosmeticSlot {
  skin('스킨'),
  accessory('액세서리');

  const CosmeticSlot(this.label);

  final String label;
}

/// 뽑기로 얻는 스킨·액세서리. [id]는 DB와 백업에 그대로 남으므로 바꾸지 않는다.
class Cosmetic {
  const Cosmetic(this.id, this.name, this.slot, this.grade);

  final String id;
  final String name;
  final CosmeticSlot slot;
  final Grade grade;

  /// 이 아이템 하나가 나올 확률(%): 등급 확률을 그 등급 아이템 수로 나눈다.
  double get percent =>
      grade.percent / cosmetics.where((c) => c.grade == grade).length;

  static Cosmetic? byId(String? id) =>
      cosmetics.where((c) => c.id == id).firstOrNull;
}

/// 뽑기 풀: 스킨 6, 액세서리 6, 모두 12종.
const cosmetics = [
  Cosmetic('skin_mint', '민트 스킨', CosmeticSlot.skin, Grade.common),
  Cosmetic('skin_peach', '복숭아 스킨', CosmeticSlot.skin, Grade.common),
  Cosmetic('skin_sky', '하늘 스킨', CosmeticSlot.skin, Grade.common),
  Cosmetic('acc_ribbon', '리본', CosmeticSlot.accessory, Grade.common),
  Cosmetic('acc_glasses', '동그란 안경', CosmeticSlot.accessory, Grade.common),
  Cosmetic('acc_cap', '야구 모자', CosmeticSlot.accessory, Grade.common),
  Cosmetic('skin_lavender', '라벤더 스킨', CosmeticSlot.skin, Grade.rare),
  Cosmetic('skin_sunset', '노을 스킨', CosmeticSlot.skin, Grade.rare),
  Cosmetic('acc_headphones', '헤드폰', CosmeticSlot.accessory, Grade.rare),
  Cosmetic('acc_scarf', '목도리', CosmeticSlot.accessory, Grade.rare),
  Cosmetic('skin_galaxy', '별빛 스킨', CosmeticSlot.skin, Grade.unique),
  Cosmetic('acc_wings', '작은 날개', CosmeticSlot.accessory, Grade.unique),
];

/// 공개한 확률대로 하나 뽑는다: 등급을 먼저 고르고, 그 등급 안에서 고르게 고른다.
Cosmetic drawCosmetic(Random random) {
  var roll = random.nextInt(100);
  var grade = Grade.values.last;
  for (final g in Grade.values) {
    if (roll < g.percent) {
      grade = g;
      break;
    }
    roll -= g.percent;
  }
  final pool = [
    for (final c in cosmetics)
      if (c.grade == grade) c,
  ];
  return pool[random.nextInt(pool.length)];
}
