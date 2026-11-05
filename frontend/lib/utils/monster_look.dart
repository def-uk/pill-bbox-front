import 'dart:math';

import '../data/models/appearance.dart';

/// 처방 몬스터의 생김새. 병명과 약 이름을 쓰지 않고 처방 속 약의 색과 모양으로만 만든다 (docs/MVP.md 5.1).
typedef MonsterLook = ({String color, String shape});

/// 생김새를 모를 때의 이름.
const defaultMonsterName = '처방 몬스터';

/// 약 생김새를 모르거나 다른 모습을 원할 때 고르는 생김새. 병명·약 이름과 상관없다.
const presetMonsterLooks = <MonsterLook>[
  (color: '주황', shape: '동글'),
  (color: '초록', shape: '길쭉'),
  (color: '파랑', shape: '캡슐'),
  (color: '분홍', shape: '동글'),
  (color: '노랑', shape: '각진'),
  (color: '보라', shape: '길쭉'),
];

String monsterName(MonsterLook? look) =>
    look == null ? defaultMonsterName : '${look.color} ${look.shape} 몬스터';

/// 식약처 생김새(색 목록, 모양)로. 색을 모르면 null.
MonsterLook? lookFromDrug(List<String> colors, String? shape) {
  final color = colors
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .firstOrNull;
  if (color == null) return null;
  final s = shape ?? '';
  return (
    color: color,
    shape: switch (s) {
      _ when s.contains('캡슐') => '캡슐',
      '원형' => '동글',
      '타원형' || '장방형' => '길쭉',
      '' => '동글',
      _ => '각진',
    },
  );
}

/// 사진으로 남긴 색·모양들의 평균으로. 없으면 null.
MonsterLook? lookFromAppearances(List<Appearance> appearances) {
  if (appearances.isEmpty) return null;
  double mean(double Function(Appearance) f) =>
      appearances.map(f).reduce((x, y) => x + y) / appearances.length;
  final l = mean((a) => a.l), a = mean((a) => a.a), b = mean((a) => a.b);
  final elongation = exp(mean((a) => log(a.elongation)));
  return (color: labColorName(l, a, b), shape: elongation >= 1.4 ? '길쭉' : '동글');
}

/// CIELAB 색의 한국어 이름. 채도가 낮으면 밝기로 하양·회색·검정, 아니면 색상각으로 나눈다.
String labColorName(double l, double a, double b) {
  final chroma = sqrt(a * a + b * b);
  if (chroma < 12) {
    if (l >= 75) return '하양';
    if (l <= 35) return '검정';
    return '회색';
  }
  final hue = (atan2(b, a) * 180 / pi + 360) % 360;
  return switch (hue) {
    < 25 || >= 345 => '분홍',
    < 60 => '빨강',
    < 85 => '주황',
    < 115 => '노랑',
    < 210 => '초록',
    < 315 => '파랑',
    _ => '보라',
  };
}
