import 'package:flutter/material.dart';

import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';
import 'creature_art.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// 몬스터 체력 막대 색.
const hpColor = Color(0xFFF0525B);

/// 얇은 둥근 막대. [value]는 0~1.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.track = AppColors.surface,
  });

  final double value;
  final Color color;
  final double height;

  /// 막대 바탕 색. 흰 면 위에 둘 때는 다른 색을 준다.
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: track,
      ),
    );
  }
}

/// 몬스터 그림, 이름, 체력 막대. 약 이름·병명은 나오지 않는다.
class MonsterFigure extends StatelessWidget {
  const MonsterFigure({
    super.key,
    required this.prescriptionId,
    required this.look,
    required this.hp,
    required this.maxHp,
    this.size = 72,
    this.defeated = false,
    this.caption,
    this.onTap,
    this.width,
  });

  /// 폭. null이면 부모가 정한 폭을 쓴다.
  final double? width;

  final int prescriptionId;
  final MonsterLook? look;
  final int hp;
  final int maxHp;
  final double size;
  final bool defeated;

  /// 체력 아래 한 줄. 예: "오늘 -1".
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = monsterName(look);
    return Semantics(
      button: onTap != null,
      label: '$name 체력 $hp / $maxHp${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonsterArt(
                  body: monsterBodyOf(prescriptionId, look),
                  color: monsterColor(look?.color),
                  size: size,
                  defeated: defeated,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.captionStrong,
                ),
                const SizedBox(height: AppSpacing.xxs),
                MeterBar(
                  value: maxHp == 0 ? 0 : hp / maxHp,
                  color: hpColor,
                  height: 6,
                ),
                const SizedBox(height: 2),
                Text(
                  '체력 $hp / $maxHp',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkMuted,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: AppTypography.captionStrong.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 성장 단계와 다음 단계까지의 경험치 막대.
class GrowthBar extends StatelessWidget {
  const GrowthBar({super.key, required this.growth});

  final Growth growth;

  @override
  Widget build(BuildContext context) {
    final next = growth.stage.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(growth.stage.label, style: AppTypography.bodyStrong),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '경험치 ${growth.exp}',
              style: AppTypography.caption.copyWith(
                color: AppColors.inkMuted,
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const Spacer(),
            Text(
              next == null ? '다 자랐어요' : '${next.label}까지 ${growth.toNext}',
              style: AppTypography.caption.copyWith(
                color: AppColors.inkMuted,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        MeterBar(
          value: growth.progress,
          color: AppColors.primary,
          track: AppColors.primarySoft,
        ),
      ],
    );
  }
}

/// 홈의 무대 (docs/MVP.md 6.4). 하늘과 언덕 가운데에 내 캐릭터가 서 있고,
/// 아래에 싸우는 중인 처방 몬스터가 줄지어 있다.
class StageCard extends StatelessWidget {
  const StageCard({
    super.key,
    required this.growth,
    required this.monsters,
    required this.looks,
    required this.today,
    required this.onTapMonster,
    this.skinId,
    this.accessoryId,
    this.pet,
    this.hud,
  });

  final String? skinId;
  final String? accessoryId;

  /// 데리고 다니는 펫: (처방 id, 생김새).
  final (int, MonsterLook?)? pet;

  /// 하늘 위쪽에 얹는 줄(날짜, 뽑기권, 메뉴).
  final Widget? hud;

  final Growth growth;
  final List<MonsterState> monsters;
  final Map<int, MonsterLook?> looks;
  final DateTime today;
  final void Function(MonsterState) onTapMonster;

  /// 언덕 높이. 성장 막대가 여기 놓인다.
  static const _ground = 100.0;

  /// 캐릭터 발이 언덕에 묻히는 깊이.
  static const _sink = 22.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final scene = (screen.height * 0.5).clamp(300.0, 440.0);
    final character = (scene * 0.5).clamp(140.0, 210.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: top + scene,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: _BackdropPainter(ground: _ground, sink: _sink),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _ground - _sink,
                child: Center(
                  child: _Bobbing(
                    child: CharacterWithPet(
                      stageExp: growth.exp,
                      skinId: skinId,
                      accessoryId: accessoryId,
                      pet: pet,
                      size: character,
                    ),
                  ),
                ),
              ),
              if (hud != null)
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: ContentWidth(child: hud!),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.sm,
                child: ContentWidth(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.lg),
                      ),
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: GrowthBar(growth: growth),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ContentWidth(
          child: _MonsterLineup(
            monsters: monsters,
            looks: looks,
            today: today,
            onTap: onTapMonster,
          ),
        ),
      ],
    );
  }
}

/// 싸우는 중인 처방 몬스터 줄.
class _MonsterLineup extends StatelessWidget {
  const _MonsterLineup({
    required this.monsters,
    required this.looks,
    required this.today,
    required this.onTap,
  });

  final List<MonsterState> monsters;
  final Map<int, MonsterLook?> looks;
  final DateTime today;
  final void Function(MonsterState) onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppLayout.compact;
    final size = compact ? 56.0 : 64.0;
    Widget figure(MonsterState m, {double? width}) => MonsterFigure(
      prescriptionId: m.prescription.id,
      look: looks[m.prescription.id],
      hp: m.hp,
      maxHp: m.maxHp,
      size: size,
      width: width,
      caption: m.attackedOn(today) ? '오늘 -1' : null,
      onTap: () => onTap(m),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 20,
                    color: hpColor,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text('싸우는 몬스터', style: AppTypography.bodyStrong),
                  const Spacer(),
                  if (monsters.isNotEmpty)
                    Text(
                      '${monsters.length}마리',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: monsters.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '싸우는 중인 몬스터가 없어요. '
                        '처방을 등록하면 새 몬스터가 나타나요.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  : monsters.length <= 3
                  // 셋까지는 폭을 나눠 쓰고, 더 많으면 옆으로 넘겨 본다.
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final m in monsters) Expanded(child: figure(m)),
                      ],
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final m in monsters) figure(m, width: size + 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 캐릭터가 숨 쉬듯 위아래로 살짝 움직인다. 애니메이션을 줄였으면 가만히 있다.
class _Bobbing extends StatefulWidget {
  const _Bobbing({required this.child});

  final Widget child;

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOf(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// 무대 배경: 보라 하늘, 구름, 반짝이, 뒷산과 캐릭터가 서는 언덕.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.ground, required this.sink});

  /// 앞 언덕 높이(아래에서부터).
  final double ground;

  /// 캐릭터 발이 언덕 꼭대기에서 묻히는 깊이. 그림자를 여기 둔다.
  final double sink;

  static const _skyTop = Color(0xFF9483FF);
  static const _skyBottom = Color(0xFFE6E0FF);
  static const _farHill = Color(0xFFCBC0FF);
  static const _hill = AppColors.canvas;
  static const _hillRim = AppColors.surfaceSunken;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
        ).createShader(rect),
    );

    // 해(달) 같은 둥근 빛.
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.26),
      34,
      Paint()..color = const Color(0x33FFFFFF),
    );
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.26),
      22,
      Paint()..color = const Color(0x66FFF3C4),
    );

    // 구름.
    _cloud(canvas, Offset(w * 0.16, h * 0.3), 1.0);
    _cloud(canvas, Offset(w * 0.62, h * 0.42), 0.75);
    _cloud(canvas, Offset(w * 0.92, h * 0.55), 0.6);

    // 반짝이.
    for (final (x, y, r) in const [
      (0.08, 0.5, 5.0),
      (0.3, 0.2, 4.0),
      (0.48, 0.32, 3.0),
      (0.72, 0.16, 5.0),
      (0.88, 0.4, 3.5),
    ]) {
      _sparkle(canvas, Offset(w * x, h * y), r);
    }

    final hillTop = h - ground;

    // 뒷산 두 봉우리.
    canvas.drawPath(
      Path()
        ..moveTo(0, hillTop + 6)
        ..quadraticBezierTo(w * 0.18, hillTop - 46, w * 0.38, hillTop + 4)
        ..quadraticBezierTo(w * 0.7, hillTop - 60, w, hillTop - 4)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = _farHill,
    );

    // 앞 언덕. 아래 화면 바탕과 같은 색이라 이어져 보인다.
    final hill = Path()
      ..moveTo(0, hillTop + 26)
      ..quadraticBezierTo(w / 2, hillTop - 26, w, hillTop + 26)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = _hill);
    canvas.drawPath(
      Path()
        ..moveTo(0, hillTop + 26)
        ..quadraticBezierTo(w / 2, hillTop - 26, w, hillTop + 26),
      Paint()
        ..color = _hillRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 캐릭터 발밑 그림자.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h - ground + sink - 2),
        width: 120,
        height: 16,
      ),
      Paint()..color = const Color(0x221B1830),
    );
  }

  void _cloud(Canvas canvas, Offset at, double scale) {
    final paint = Paint()..color = const Color(0xCCFFFFFF);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-40, -8, 80, 22),
        const Radius.circular(11),
      ),
      paint,
    );
    canvas.drawCircle(const Offset(-14, -8), 14, paint);
    canvas.drawCircle(const Offset(10, -12), 18, paint);
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = const Color(0xE6FFFFFF);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.ground != ground || old.sink != sink;
}
