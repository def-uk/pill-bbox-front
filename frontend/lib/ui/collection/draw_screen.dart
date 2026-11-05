import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/reward_calculator.dart';
import '../common/cosmetic_widgets.dart';
import '../common/motion.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'draw_view_model.dart';

class DrawScreen extends StatelessWidget {
  const DrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DrawViewModel>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('뽑기')),
      body: switch (vm) {
        DrawViewModel(loading: true) => const LoadingState(),
        _ => ListView(
          padding: pagePadding(context, top: AppSpacing.lg),
          children: [
            Text(
              '뽑기권 ${vm.tickets}장',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '일정을 $ticketStreakDays일 연속으로 지키면 1장, 몬스터를 퇴치하면 1장\n'
              '지금 ${vm.streak}일 연속 · 다음 뽑기권까지 ${vm.daysToNextTicket}일',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            if (vm.result case (:final cosmetic, :final count)) ...[
              const SizedBox(height: AppSpacing.lg),
              DrawReveal(
                key: ValueKey(vm.drawSerial),
                cosmetic: cosmetic,
                count: count,
              ),
            ],
            const SectionLabel('확률'),
            GroupCard(
              children: [
                for (final grade in Grade.values)
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Row(
                      children: [
                        GradeBadge(grade),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${grade.percent}%',
                          style: AppTypography.bodyStrong.copyWith(
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      for (final c in cosmetics)
                        if (c.grade == grade)
                          ListTile(
                            dense: true,
                            title: Text('${c.name} · ${c.slot.label}'),
                            trailing: Text(
                              '${c.percent.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '뽑기는 무료예요. 뽑기권은 기록으로만 얻고 팔지 않아요.',
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      },
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: vm.canDraw ? vm.draw : null,
              child: Text(vm.tickets > 0 ? '뽑기권 1장으로 뽑기' : '뽑기권이 없어요'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 뽑기 연출 (docs/MVP.md 8장): 캡슐이 흔들리다 열리고, 등급 색으로 번쩍이며 아이템이 튀어나온다.
/// 유니크는 뒤에 빛줄기가 돈다. 누르면 끝까지 넘긴다.
class DrawReveal extends StatefulWidget {
  const DrawReveal({super.key, required this.cosmetic, required this.count});

  final Cosmetic cosmetic;
  final int count;

  static const duration = Duration(milliseconds: 1600);

  @override
  State<DrawReveal> createState() => DrawRevealState();
}

class DrawRevealState extends State<DrawReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: DrawReveal.duration,
  );

  static const _shake = Interval(0, 0.45);
  static const _open = Interval(0.45, 0.62, curve: Curves.easeOut);
  static const _item = Interval(0.5, 1, curve: Curves.elasticOut);
  static const _label = Interval(0.65, 0.85);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (motionOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cosmetic = widget.cosmetic;
    final color = gradeColor(cosmetic.grade);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_controller.isAnimating) _controller.value = 1;
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final shake = _shake.transform(t);
              final open = _open.transform(t);
              final item = _item.transform(t);
              final label = _label.transform(t);
              return Column(
                children: [
                  SizedBox.square(
                    dimension: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (cosmetic.grade == Grade.unique && open > 0)
                          Transform.rotate(
                            angle: t * pi,
                            child: CustomPaint(
                              size: const Size.square(140),
                              painter: _RaysPainter(
                                color.withValues(alpha: 0.35 * open),
                              ),
                            ),
                          ),
                        // 열리는 순간 등급 색으로 번쩍인다.
                        if (open > 0 && open < 1)
                          Container(
                            width: 140 * open,
                            height: 140 * open,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.4 * (1 - open)),
                            ),
                          ),
                        if (item > 0)
                          Transform.scale(
                            scale: item,
                            child: CosmeticPreview(
                              cosmetic: cosmetic,
                              size: 120,
                            ),
                          ),
                        if (open < 1)
                          Transform.rotate(
                            angle: sin(shake * pi * 8) * 0.18 * shake,
                            child: _Capsule(open: open),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Opacity(
                    opacity: label,
                    child: Column(
                      children: [
                        GradeBadge(cosmetic.grade),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          cosmetic.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.count > 1
                              ? '이미 있는 아이템이에요 · ${widget.count}개째'
                              : '새 ${cosmetic.slot.label}! 컬렉션에서 장착할 수 있어요',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_controller.isAnimating)
                    Text(
                      '눌러서 건너뛰기',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 뽑기 캡슐. [open]이 커질수록 위·아래 반쪽이 벌어지며 사라진다.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.open});

  final double open;

  @override
  Widget build(BuildContext context) {
    Widget half({required bool top}) => Transform.translate(
      offset: Offset(0, (top ? -1 : 1) * 40 * open),
      child: Opacity(
        opacity: 1 - open,
        child: ClipRect(
          child: Align(
            alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
            heightFactor: 0.5,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: top ? AppColors.primary : AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [half(top: true), half(top: false)],
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = color;
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + cos(a - 0.12) * size.width / 2,
            center.dy + sin(a - 0.12) * size.height / 2,
          )
          ..lineTo(
            center.dx + cos(a + 0.12) * size.width / 2,
            center.dy + sin(a + 0.12) * size.height / 2,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}
