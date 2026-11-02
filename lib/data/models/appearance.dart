import 'dart:math';

/// 사진 속 물체 하나의 색과 모양. 사용자가 고른 약과 함께 저장해 두고, 다음 사진에서 비슷한 약을 추천한다.
class Appearance {
  const Appearance({
    required this.l,
    required this.a,
    required this.b,
    required this.elongation,
  });

  factory Appearance.fromMap(Map<String, Object?> map) => Appearance(
    l: (map['l']! as num).toDouble(),
    a: (map['a']! as num).toDouble(),
    b: (map['b']! as num).toDouble(),
    elongation: (map['elongation']! as num).toDouble(),
  );

  /// 이 거리보다 가까우면 비슷한 약으로 추천한다. 대회 학습 데이터에서 같은 약끼리는 94%가 이 안에,
  /// 다른 약끼리는 5%만 이 안에 들었다.
  static const similarDistance = 2.0;

  /// 물체 픽셀의 평균 색 (CIELAB).
  final double l;
  final double a;
  final double b;

  /// 긴 축과 짧은 축 길이의 비. 둥글면 1, 길쭉할수록 커진다. 돌려 찍어도 같다.
  final double elongation;

  Map<String, Object?> toMap() => {
    'l': l,
    'a': a,
    'b': b,
    'elongation': elongation,
  };

  /// 같은 약끼리 대략 1 안팎이 되도록 항목마다 허용 차이로 나눈 거리.
  ///
  /// 길쭉함은 비율로 비교한다. 아주 길쭉한 물체는 테두리 1픽셀에도 값이 크게 흔들려(7.6과 8.1),
  /// 차이로 비교하면 같은 물체를 다르다고 본다.
  double distanceTo(Appearance other) {
    double d(double x, double y, double tolerance) => (x - y) / tolerance;
    return sqrt(
      pow(d(l, other.l, 10), 2) +
          pow(d(a, other.a, 6), 2) +
          pow(d(b, other.b, 6), 2) +
          pow(d(log(elongation), log(other.elongation), 0.15), 2),
    );
  }
}
