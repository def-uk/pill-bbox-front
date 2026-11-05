import 'package:flutter/material.dart';

import '../../utils/character.dart';
import '../../utils/monster_look.dart';
import '../../utils/reward_calculator.dart';
import 'creature_art.dart';
import 'theme.dart';

/// 몬스터 체력 막대 색.
const hpColor = Color(0xFFF0525B);

/// 얇은 둥근 막대. [value]는 0~1.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: AppColors.surface,
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
        MeterBar(value: growth.progress, color: AppColors.primary),
      ],
    );
  }
}

/// 홈 맨 위 무대: 내 캐릭터와 싸우는 중인 처방 몬스터 (docs/MVP.md 6.4).
class StageCard extends StatelessWidget {
  const StageCard({
    super.key,
    required this.growth,
    required this.monsters,
    required this.looks,
    required this.today,
    required this.onTapMonster,
  });

  final Growth growth;
  final List<MonsterState> monsters;
  final Map<int, MonsterLook?> looks;
  final DateTime today;
  final void Function(MonsterState) onTapMonster;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppLayout.compact;
    final monsterSize = compact ? 56.0 : 64.0;
    Widget figure(MonsterState m, {double? width}) => MonsterFigure(
      prescriptionId: m.prescription.id,
      look: looks[m.prescription.id],
      hp: m.hp,
      maxHp: m.maxHp,
      size: monsterSize,
      width: width,
      caption: m.attackedOn(today) ? '오늘 -1' : null,
      onTap: () => onTapMonster(m),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CharacterArt(stage: growth.stage, size: compact ? 96 : 124),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: monsters.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            '처방을 등록하면 몬스터가 나타나요.\n'
                            '영양제 일정을 사진으로 지키면 캐릭터가 자라요.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        )
                      : monsters.length <= 2
                      // 둘까지는 남은 폭을 나눠 쓰고, 더 많으면 옆으로 넘겨 본다.
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final m in monsters)
                              Expanded(child: figure(m)),
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final m in monsters)
                                figure(m, width: monsterSize + 32),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            GrowthBar(growth: growth),
          ],
        ),
      ),
    );
  }
}
