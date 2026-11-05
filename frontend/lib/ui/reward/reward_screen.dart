import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';
import '../common/creature_art.dart';
import '../common/motion.dart';
import '../common/stage_widgets.dart';
import '../common/theme.dart';
import '../common/widgets.dart';

/// 저장 직후 보상 결과 (docs/MVP.md 6.4, 8장): 몬스터가 맞고 체력 막대가 줄고, 퇴치하면 쓰러져 펫이 되고,
/// 경험치 막대가 차오르며 단계가 오르면 캐릭터가 바뀐다.
///
/// 연출은 화면을 누르거나 건너뛰기로 끝까지 넘긴다. 시스템에서 애니메이션을 끄면 끝난 모습만 보여 준다.
/// 바뀐 숫자("체력 7 → 6")는 연출과 상관없이 늘 글로 보인다.
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key, required this.outcome, required this.looks});

  final RewardOutcome outcome;
  final Map<int, MonsterLook?> looks;

  /// 연출 길이.
  static const duration = Duration(milliseconds: 2400);

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: RewardScreen.duration,
  );

  // 연출 구간 (0~1).
  static const _hit = Interval(0.05, 0.35, curve: Curves.easeOut);
  static const _fall = Interval(0.35, 0.5, curve: Curves.easeIn);
  static const _pet = Interval(0.5, 0.68, curve: Curves.elasticOut);
  static const _exp = Interval(0.45, 0.95, curve: Curves.easeInOut);

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

  void _skip() {
    if (_controller.isAnimating) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final textTheme = Theme.of(context).textTheme;
    final grew =
        CharacterStage.of(outcome.expAfter) !=
        CharacterStage.of(outcome.expBefore);
    return Scaffold(
      appBar: AppBar(
        title: const Text('보상'),
        automaticallyImplyLeading: false,
        actionsPadding: EdgeInsets.only(right: gutterOf(context) - 12),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _controller.isAnimating
                ? TextButton(onPressed: _skip, child: const Text('건너뛰기'))
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final exp =
                outcome.expBefore +
                (outcome.expAfter - outcome.expBefore) * _exp.transform(t);
            return ListView(
              padding: pagePadding(context, top: AppSpacing.md),
              children: [
                Text(
                  '복용 기록을 저장했어요',
                  textAlign: TextAlign.center,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (outcome.monsters.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.sm,
                    children: [
                      for (final change in outcome.monsters)
                        Expanded(
                          child: _MonsterResult(
                            change: change,
                            look: widget.looks[change.after.prescription.id],
                            size: outcome.monsters.length == 1 ? 120 : 88,
                            hit: _hit.transform(t),
                            fall: _fall.transform(t),
                            pet: _pet.transform(t),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Center(
                  child: AnimatedSwitcher(
                    duration: motionOf(context)
                        ? const Duration(milliseconds: 600)
                        : Duration.zero,
                    switchInCurve: Curves.elasticOut,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: CharacterArt(
                      key: ValueKey(CharacterStage.of(exp.floor())),
                      stage: CharacterStage.of(exp.floor()),
                      size: 140,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  grew
                      ? '${CharacterStage.of(outcome.expAfter).label}(으)로 자랐어요!'
                      : outcome.expGained > 0
                      ? '경험치 +${outcome.expGained}'
                      : '오늘 영양제 일정을 다 지키면 경험치 +$supplementDayExp',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ExpBar(exp: exp),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '경험치 ${outcome.expBefore} → ${outcome.expAfter}',
                  textAlign: TextAlign.center,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.inkMuted,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          // 퇴치했으면 얻은 펫과 퇴치 기록을 컬렉션에서 바로 본다 (상황 A · 8쪽).
          if (outcome.monsters.any((m) => m.after.isDefeated))
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.go('/collection'),
                child: const Text('컬렉션에 전시'),
              ),
            ),
          Expanded(
            child: FilledButton(
              onPressed: () => context.pop(),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 차오르는 경험치 막대. [exp]는 연출 중 소수가 된다.
class _ExpBar extends StatelessWidget {
  const _ExpBar({required this.exp});

  final double exp;

  @override
  Widget build(BuildContext context) {
    final growth = Growth(exp.floor());
    final next = growth.stage.next;
    final progress = next == null
        ? 1.0
        : (exp - growth.stage.minExp) / (next.minExp - growth.stage.minExp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(growth.stage.label, style: AppTypography.bodyStrong),
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
        MeterBar(value: progress, color: AppColors.primary),
      ],
    );
  }
}

class _MonsterResult extends StatelessWidget {
  const _MonsterResult({
    required this.change,
    required this.look,
    required this.size,
    required this.hit,
    required this.fall,
    required this.pet,
  });

  final MonsterChange change;
  final MonsterLook? look;
  final double size;

  /// 맞는 연출 0~1. 체력 막대가 줄고 몬스터가 흔들린다.
  final double hit;

  /// 쓰러지는 연출 0~1. 퇴치한 몬스터만.
  final double fall;

  /// 펫이 나타나는 연출 0~1. 퇴치한 몬스터만.
  final double pet;

  @override
  Widget build(BuildContext context) {
    final (:before, :after) = change;
    final name = monsterName(look);
    final defeated = after.isDefeated;
    final hp = before.hp + (after.hp - before.hp) * hit;
    // 맞는 동안 좌우로 흔들리고, 다 맞으면 멈춘다.
    final shake = hit > 0 && hit < 1 ? sin(hit * pi * 6) * 6 * (1 - hit) : 0.0;
    final body = monsterBodyOf(after.prescription.id, look);
    final color = monsterColor(look?.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: defeated ? 1 - 0.25 * fall : 1,
              child: MonsterArt(
                body: body,
                color: color,
                size: size,
                defeated: defeated && fall > 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong,
        ),
        Text(
          defeated ? '퇴치!' : '체력 -${before.hp - after.hp}',
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong.copyWith(
            color: defeated ? AppColors.primary : hpColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        MeterBar(
          value: after.maxHp == 0 ? 0 : hp / after.maxHp,
          color: hpColor,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '체력 ${before.hp} → ${after.hp} / ${after.maxHp}',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.inkMuted,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        if (defeated) ...[
          const SizedBox(height: AppSpacing.sm),
          Opacity(
            opacity: pet.clamp(0, 1),
            child: Column(
              children: [
                Transform.scale(
                  scale: pet.clamp(0, 1.2),
                  child: MonsterArt(
                    body: body,
                    color: color,
                    size: size * 0.5,
                    friendly: true,
                  ),
                ),
                Text(
                  '펫이 생겼어요',
                  style: AppTypography.captionStrong.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '경험치 +$defeatExp · 뽑기권 +1',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
