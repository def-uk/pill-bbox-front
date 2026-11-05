import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';
import '../common/creature_art.dart';
import '../common/stage_widgets.dart';
import '../common/theme.dart';
import '../common/widgets.dart';

/// 저장 직후 보상 결과: 몬스터 체력이 얼마나 줄었고 경험치가 얼마나 늘었는지 (docs/MVP.md 6.4).
/// 애니메이션은 5단계에서 더한다.
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key, required this.outcome, required this.looks});

  final RewardOutcome outcome;
  final Map<int, MonsterLook?> looks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final before = Growth(outcome.expBefore);
    final after = Growth(outcome.expAfter);
    final grew = after.stage != before.stage;
    return Scaffold(
      appBar: AppBar(title: const Text('보상'), automaticallyImplyLeading: false),
      body: ListView(
        padding: pagePadding(context, top: AppSpacing.md),
        children: [
          Text(
            '복용 기록을 저장했어요',
            textAlign: TextAlign.center,
            style: AppTypography.callout.copyWith(color: AppColors.inkMuted),
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
                      look: looks[change.after.prescription.id],
                      size: outcome.monsters.length == 1 ? 120 : 88,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Center(child: CharacterArt(stage: after.stage, size: 140)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            grew
                ? '${after.stage.label}(으)로 자랐어요!'
                : outcome.expGained > 0
                ? '경험치 +${outcome.expGained}'
                : '오늘 영양제 일정을 다 지키면 경험치 +$supplementDayExp',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          GrowthBar(growth: after),
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
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
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

class _MonsterResult extends StatelessWidget {
  const _MonsterResult({
    required this.change,
    required this.look,
    required this.size,
  });

  final MonsterChange change;
  final MonsterLook? look;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (:before, :after) = change;
    final name = monsterName(look);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MonsterArt(
            body: monsterBodyOf(after.prescription.id, look),
            color: monsterColor(look?.color),
            size: size,
            defeated: after.isDefeated,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong,
        ),
        Text(
          after.isDefeated ? '퇴치!' : '체력 -${before.hp - after.hp}',
          textAlign: TextAlign.center,
          style: AppTypography.bodyStrong.copyWith(
            color: after.isDefeated ? AppColors.primary : hpColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        MeterBar(
          value: after.maxHp == 0 ? 0 : after.hp / after.maxHp,
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
        if (after.isDefeated)
          Text(
            '경험치 +$defeatExp',
            textAlign: TextAlign.center,
            style: AppTypography.captionStrong.copyWith(
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}
