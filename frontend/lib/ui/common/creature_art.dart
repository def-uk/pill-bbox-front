import 'dart:math';

import 'package:flutter/material.dart';

import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import 'theme.dart';

/// 캐릭터와 몬스터 그림. 아이콘 캐릭터(assets/icon/app_icon.png)의 화풍(테두리 없는 납작한 면, 남보라 눈,
/// 크림색 배)을 코드로 그린다. 디자인한 에셋이 나오면 이 파일만 바꾸면 된다 (docs/MVP.md 10장).
abstract final class CreatureColors {
  /// 아이콘 캐릭터의 라임색.
  static const lime = Color(0xFFCCFF3A);
  static const limeShade = Color(0xFFA9DB1F);

  /// 눈·입. 아이콘의 짙은 남보라.
  static const feature = Color(0xFF2B1D9E);
  static const belly = AppColors.cream;
  static const blush = Color(0x55FF7AA8);
  static const crown = Color(0xFFFFC93C);

  /// 생김새를 모르는 몬스터.
  static const unknownMonster = Color(0xFFB6AEE0);
}

/// 식약처·사진 색 이름 → 몬스터 몸 색. 모르는 이름이면 [CreatureColors.unknownMonster].
Color monsterColor(String? colorName) => switch (colorName) {
  null => CreatureColors.unknownMonster,
  final n when n.contains('하양') || n.contains('흰') => const Color(0xFFF7F3EA),
  final n when n.contains('연두') => const Color(0xFFA9E34B),
  final n when n.contains('노랑') || n.contains('노란') => const Color(0xFFFFD43B),
  final n when n.contains('주황') => const Color(0xFFFF922B),
  final n when n.contains('분홍') => const Color(0xFFFF8FB1),
  final n when n.contains('빨강') || n.contains('빨간') => const Color(0xFFF05252),
  final n when n.contains('갈색') => const Color(0xFFB07A4F),
  final n when n.contains('청록') => const Color(0xFF20C9A6),
  final n when n.contains('초록') => const Color(0xFF51CF66),
  final n when n.contains('남색') => const Color(0xFF4A5BD8),
  final n when n.contains('파랑') => const Color(0xFF5C8DFF),
  final n when n.contains('보라') => const Color(0xFFA27BFF),
  final n when n.contains('자주') => const Color(0xFFD6457F),
  final n when n.contains('회색') => const Color(0xFFB8BCC8),
  final n when n.contains('검정') => const Color(0xFF5B5D6B),
  final n when n.contains('투명') => const Color(0xFFDDE4EE),
  _ => CreatureColors.unknownMonster,
};

/// 기본 몬스터 6종 (docs/MVP.md 6.2).
enum MonsterBody { blob, capsule, spiky, ghost, jelly, horned }

/// 처방마다 늘 같은 기본 몬스터. 캡슐·길쭉한 약은 캡슐 몬스터.
MonsterBody monsterBodyOf(int prescriptionId, MonsterLook? look) {
  if (look?.shape == '캡슐' || look?.shape == '길쭉') return MonsterBody.capsule;
  final others = [
    for (final b in MonsterBody.values)
      if (b != MonsterBody.capsule) b,
  ];
  return others[prescriptionId % others.length];
}

/// 내 캐릭터. 단계가 오를수록 크고 갖춰진다.
class CharacterArt extends StatelessWidget {
  const CharacterArt({super.key, required this.stage, this.size = 120});

  final CharacterStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '내 캐릭터 · ${stage.label}',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _CharacterPainter(stage),
      ),
    );
  }
}

/// 처방 몬스터. [defeated]면 흐리게.
class MonsterArt extends StatelessWidget {
  const MonsterArt({
    super.key,
    required this.body,
    required this.color,
    this.size = 88,
    this.defeated = false,
  });

  final MonsterBody body;
  final Color color;
  final double size;
  final bool defeated;

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(
      size: Size.square(size),
      painter: _MonsterPainter(body, color, defeated: defeated),
    );
    return ExcludeSemantics(
      child: defeated ? Opacity(opacity: 0.45, child: art) : art,
    );
  }
}

/// 100×100 좌표로 그리고 캔버스 크기에 맞춘다. [scale]만큼 줄여 바닥 가운데에 세운다.
void _inBox(Canvas canvas, Size size, double scale, void Function() draw) {
  canvas.save();
  final s = size.shortestSide / 100;
  canvas.translate(
    (size.width - 100 * s * scale) / 2,
    size.height - 100 * s * scale,
  );
  canvas.scale(s * scale);
  draw();
  canvas.restore();
}

Paint _fill(Color color) => Paint()
  ..color = color
  ..isAntiAlias = true;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

class _CharacterPainter extends CustomPainter {
  _CharacterPainter(this.stage);

  final CharacterStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = switch (stage) {
      CharacterStage.egg => 0.62,
      CharacterStage.baby => 0.62,
      CharacterStage.child => 0.78,
      CharacterStage.grown => 0.9,
      CharacterStage.complete => 1.0,
    };
    _inBox(canvas, size, scale, () {
      switch (stage) {
        case CharacterStage.egg:
          _egg(canvas);
        case CharacterStage.baby:
          _baby(canvas);
        case CharacterStage.child:
          _body(canvas, ears: _Ears.nubs, belly: false);
        case CharacterStage.grown:
          _body(canvas, ears: _Ears.full, belly: true);
        case CharacterStage.complete:
          _body(canvas, ears: _Ears.full, belly: true, mark: true);
          _crown(canvas);
      }
    });
  }

  void _egg(Canvas canvas) {
    final egg = Path()
      ..moveTo(50, 6)
      ..cubicTo(74, 6, 88, 48, 88, 64)
      ..cubicTo(88, 84, 72, 98, 50, 98)
      ..cubicTo(28, 98, 12, 84, 12, 64)
      ..cubicTo(12, 48, 26, 6, 50, 6)
      ..close();
    canvas.drawPath(egg, _fill(Colors.white));
    canvas.save();
    canvas.clipPath(egg);
    // 라임 무늬 띠와 점.
    final band = Path()..moveTo(0, 62);
    for (var x = 0.0; x <= 100; x += 10) {
      band.lineTo(x + 5, x % 20 == 0 ? 54 : 62);
    }
    band
      ..lineTo(100, 74)
      ..lineTo(0, 74)
      ..close();
    canvas.drawPath(band, _fill(CreatureColors.lime));
    canvas.drawCircle(const Offset(36, 30), 6, _fill(CreatureColors.lime));
    canvas.drawCircle(const Offset(62, 22), 4, _fill(CreatureColors.lime));
    canvas.drawCircle(const Offset(66, 86), 5, _fill(CreatureColors.lime));
    canvas.restore();
    canvas.drawPath(egg, _stroke(CreatureColors.limeShade, 3));
    // 금 간 자리.
    canvas.drawPath(
      Path()
        ..moveTo(56, 34)
        ..lineTo(62, 40)
        ..lineTo(58, 44)
        ..lineTo(64, 50),
      _stroke(CreatureColors.feature, 2.4),
    );
  }

  void _baby(Canvas canvas) {
    final body = Path()
      ..moveTo(50, 22)
      ..cubicTo(78, 22, 92, 50, 92, 70)
      ..cubicTo(92, 90, 74, 98, 50, 98)
      ..cubicTo(26, 98, 8, 90, 8, 70)
      ..cubicTo(8, 50, 22, 22, 50, 22)
      ..close();
    canvas.drawPath(body, _fill(CreatureColors.lime));
    // 머리 위 새싹 같은 털 한 가닥.
    canvas.drawPath(
      Path()
        ..moveTo(50, 24)
        ..quadraticBezierTo(46, 10, 56, 8),
      _stroke(CreatureColors.limeShade, 4),
    );
    _face(canvas, eyeY: 58, eyeGap: 15, eyeH: 9);
    canvas.drawCircle(const Offset(28, 70), 5, _fill(CreatureColors.blush));
    canvas.drawCircle(const Offset(72, 70), 5, _fill(CreatureColors.blush));
  }

  void _body(
    Canvas canvas, {
    required _Ears ears,
    required bool belly,
    bool mark = false,
  }) {
    final lime = _fill(CreatureColors.lime);
    if (ears == _Ears.full) {
      // 아이콘처럼 왼쪽은 뾰족한 귀, 오른쪽은 접힌 귀.
      canvas.drawPath(
        Path()
          ..moveTo(22, 40)
          ..quadraticBezierTo(18, 12, 28, 6)
          ..quadraticBezierTo(38, 10, 48, 24)
          ..close(),
        lime,
      );
      canvas.drawPath(
        Path()
          ..moveTo(56, 24)
          ..quadraticBezierTo(70, 14, 82, 16)
          ..quadraticBezierTo(96, 20, 92, 28)
          ..quadraticBezierTo(84, 31, 78, 40)
          ..close(),
        lime,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(24, 38)
          ..quadraticBezierTo(24, 18, 32, 16)
          ..quadraticBezierTo(40, 20, 44, 28)
          ..close(),
        lime,
      );
      canvas.drawPath(
        Path()
          ..moveTo(56, 28)
          ..quadraticBezierTo(62, 18, 70, 18)
          ..quadraticBezierTo(78, 22, 76, 38)
          ..close(),
        lime,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(50, 22)
        ..cubicTo(70, 22, 80, 36, 84, 56)
        ..cubicTo(90, 82, 80, 96, 50, 96)
        ..cubicTo(20, 96, 10, 82, 16, 56)
        ..cubicTo(20, 36, 30, 22, 50, 22)
        ..close(),
      lime,
    );
    _face(canvas, eyeY: 46, eyeGap: 12, eyeH: 11);
    if (belly) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 76), width: 36, height: 24),
        _fill(CreatureColors.belly),
      );
      if (mark) {
        // 배의 m.
        canvas.drawPath(
          Path()
            ..moveTo(41, 82)
            ..lineTo(41, 74)
            ..quadraticBezierTo(41, 70, 45.5, 70)
            ..quadraticBezierTo(50, 70, 50, 74)
            ..lineTo(50, 82)
            ..moveTo(50, 74)
            ..quadraticBezierTo(50, 70, 54.5, 70)
            ..quadraticBezierTo(59, 70, 59, 74)
            ..lineTo(59, 82),
          _stroke(CreatureColors.feature, 3.6),
        );
      }
    } else {
      canvas.drawCircle(const Offset(30, 60), 4.5, _fill(CreatureColors.blush));
      canvas.drawCircle(const Offset(70, 60), 4.5, _fill(CreatureColors.blush));
    }
  }

  void _face(
    Canvas canvas, {
    required double eyeY,
    required double eyeGap,
    required double eyeH,
  }) {
    final feature = _fill(CreatureColors.feature);
    for (final x in [50 - eyeGap, 50 + eyeGap]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, eyeY), width: 6, height: eyeH),
          const Radius.circular(3),
        ),
        feature,
      );
    }
    canvas.drawArc(
      Rect.fromCenter(center: Offset(50, eyeY + 4), width: 10, height: 8),
      0.2,
      pi - 0.4,
      false,
      _stroke(CreatureColors.feature, 2.4),
    );
  }

  void _crown(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(38, 20)
        ..lineTo(36, 8)
        ..lineTo(43, 13)
        ..lineTo(50, 4)
        ..lineTo(57, 13)
        ..lineTo(64, 8)
        ..lineTo(62, 20)
        ..close(),
      _fill(CreatureColors.crown),
    );
    // 반짝임.
    for (final (c, r) in [
      (const Offset(12, 30), 4.0),
      (const Offset(90, 50), 3.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
          ..close(),
        _fill(CreatureColors.crown),
      );
    }
  }

  @override
  bool shouldRepaint(_CharacterPainter old) => old.stage != stage;
}

enum _Ears { nubs, full }

class _MonsterPainter extends CustomPainter {
  _MonsterPainter(this.body, this.color, {required this.defeated});

  final MonsterBody body;
  final Color color;
  final bool defeated;

  Color get _shade => Color.lerp(color, const Color(0xFF1B1830), 0.28)!;

  @override
  void paint(Canvas canvas, Size size) {
    _inBox(canvas, size, 0.92, () {
      final fill = _fill(color);
      final edge = _stroke(_shade, 2.4);
      final shade = _fill(_shade);
      void shape(Path p) {
        canvas.drawPath(p, fill);
        canvas.drawPath(p, edge);
      }

      switch (body) {
        case MonsterBody.blob:
          for (final x in [30.0, 70.0]) {
            canvas.drawPath(
              Path()
                ..moveTo(x - 7, 30)
                ..lineTo(x + (x < 50 ? -4 : 4), 12)
                ..lineTo(x + 7, 30)
                ..close(),
              shade,
            );
          }
          shape(Path()..addOval(const Rect.fromLTRB(10, 22, 90, 96)));
          _face(canvas, y: 56);
        case MonsterBody.capsule:
          final capsule = RRect.fromLTRBR(
            6,
            34,
            94,
            90,
            const Radius.circular(28),
          );
          canvas.save();
          canvas.clipRRect(capsule);
          canvas.drawRect(const Rect.fromLTRB(0, 0, 50, 100), fill);
          canvas.drawRect(
            const Rect.fromLTRB(50, 0, 100, 100),
            _fill(Color.lerp(color, Colors.white, 0.45)!),
          );
          canvas.restore();
          canvas.drawRRect(capsule, edge);
          _face(canvas, y: 60);
          _feet(canvas, 90);
        case MonsterBody.spiky:
          final spikes = Path();
          const n = 12;
          for (var i = 0; i <= n * 2; i++) {
            final angle = -pi / 2 + i * pi / n;
            final r = i.isEven ? 44.0 : 34.0;
            final p = Offset(50 + r * cos(angle), 58 + r * sin(angle));
            i == 0 ? spikes.moveTo(p.dx, p.dy) : spikes.lineTo(p.dx, p.dy);
          }
          shape(spikes..close());
          _face(canvas, y: 58);
        case MonsterBody.ghost:
          final ghost = Path()
            ..moveTo(14, 96)
            ..lineTo(14, 52)
            ..cubicTo(14, 26, 30, 14, 50, 14)
            ..cubicTo(70, 14, 86, 26, 86, 52)
            ..lineTo(86, 96);
          for (var x = 86.0; x > 14; x -= 18) {
            ghost.quadraticBezierTo(x - 9, 108, x - 18, 96);
          }
          shape(ghost..close());
          _face(canvas, y: 50);
        case MonsterBody.jelly:
          final jelly = Path()
            ..moveTo(10, 82)
            ..cubicTo(10, 40, 28, 22, 50, 22)
            ..cubicTo(72, 22, 90, 40, 90, 82)
            ..quadraticBezierTo(90, 90, 82, 90)
            ..lineTo(72, 90)
            ..quadraticBezierTo(68, 100, 64, 90)
            ..lineTo(40, 90)
            ..quadraticBezierTo(34, 102, 28, 90)
            ..lineTo(18, 90)
            ..quadraticBezierTo(10, 90, 10, 82)
            ..close();
          shape(jelly);
          canvas.drawCircle(
            const Offset(32, 40),
            5,
            _fill(Colors.white.withValues(alpha: 0.6)),
          );
          _face(canvas, y: 60);
        case MonsterBody.horned:
          for (final dir in [-1.0, 1.0]) {
            canvas.drawPath(
              Path()
                ..moveTo(50 + dir * 18, 30)
                ..quadraticBezierTo(50 + dir * 44, 26, 50 + dir * 40, 6)
                ..quadraticBezierTo(50 + dir * 34, 22, 50 + dir * 28, 34)
                ..close(),
              shade,
            );
          }
          shape(
            Path()..addRRect(
              RRect.fromLTRBR(14, 26, 86, 90, const Radius.circular(22)),
            ),
          );
          _face(canvas, y: 56);
          _feet(canvas, 90);
      }
    });
  }

  /// 찡그린 눈썹과 이빨 하나. 쓰러지면 X 눈.
  void _face(Canvas canvas, {required double y}) {
    final feature = _fill(CreatureColors.feature);
    final line = _stroke(CreatureColors.feature, 3);
    for (final dir in [-1.0, 1.0]) {
      final x = 50 + dir * 13;
      if (defeated) {
        canvas.drawLine(Offset(x - 4, y - 4), Offset(x + 4, y + 4), line);
        canvas.drawLine(Offset(x - 4, y + 4), Offset(x + 4, y - 4), line);
        continue;
      }
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 7, height: 9),
        feature,
      );
      // 안쪽 끝이 낮은 찡그린 눈썹.
      canvas.drawLine(
        Offset(x - dir * 6, y - 7),
        Offset(x + dir * 5, y - 12),
        line,
      );
    }
    final mouth = Path()
      ..moveTo(42, y + 12)
      ..quadraticBezierTo(50, y + 8, 58, y + 12);
    canvas.drawPath(mouth, _stroke(CreatureColors.feature, 2.6));
    if (!defeated) {
      canvas.drawPath(
        Path()
          ..moveTo(52, y + 10.4)
          ..lineTo(55, y + 15)
          ..lineTo(56.6, y + 10.9)
          ..close(),
        _fill(Colors.white),
      );
    }
  }

  void _feet(Canvas canvas, double y) {
    for (final x in [32.0, 68.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + 4), width: 16, height: 8),
        _fill(_shade),
      );
    }
  }

  @override
  bool shouldRepaint(_MonsterPainter old) =>
      old.body != body || old.color != color || old.defeated != defeated;
}
