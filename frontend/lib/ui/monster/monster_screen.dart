import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/reward_calculator.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'monster_view_model.dart';

class MonsterScreen extends StatelessWidget {
  const MonsterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MonsterViewModel>();
    final textTheme = Theme.of(context).textTheme;

    Future<void> end(MonsterState m) async {
      final ok = await confirm(
        context,
        message:
            '의사가 약을 중단했을 때만 끝내 주세요. 몬스터가 물러나고, '
            '깎은 체력 ${m.dealt}만큼 경험치를 받아요. 펫은 얻지 못해요.',
        action: '처방 끝내기',
        destructive: true,
      );
      if (ok) await vm.end();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('처방 몬스터')),
      body: switch (vm) {
        MonsterViewModel(loading: true) => const LoadingState(),
        MonsterViewModel(monster: null) => const EmptyState(
          icon: Icons.pest_control_rounded,
          title: '지워진 처방입니다',
        ),
        MonsterViewModel(monster: final m?) => ListView(
          padding: pagePadding(context, top: AppSpacing.lg),
          children: [
            Text(vm.name, style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              switch (m) {
                MonsterState(isDefeated: true) =>
                  '${formatDate(m.defeatedOn!)} 퇴치',
                MonsterState(isEnded: true) => '처방을 끝내 물러났어요',
                _ when m.prescription.isOverOn(vm.today) =>
                  '처방 기간이 끝났어요. 남은 체력은 그대로 남아요',
                _ => '그날 회차를 모두 사진으로 기록하면 체력 -1 (하루 최대 1)',
              },
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('체력', style: textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${m.hp} / ${m.maxHp}',
                  style: AppTypography.headline.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.sm),
              ),
              child: LinearProgressIndicator(
                value: m.maxHp == 0 ? 0 : m.hp / m.maxHp,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatDate(m.prescription.startDate)} ~ '
              '${formatDate(m.prescription.endDate)} · ${m.maxHp}일',
              style: AppTypography.caption.copyWith(
                color: AppColors.inkMuted,
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  '약을 놓쳤다면 의사·약사의 안내를 따르세요. '
                  '놓친 날은 체력이 줄지 않을 뿐, 벌은 없어요.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
            const SectionLabel('지난 기록'),
            if (vm.pastDays.isEmpty)
              Text(
                '${formatDate(m.prescription.startDate)}부터 시작해요',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              )
            else
              GroupCard(
                children: [
                  for (final day in vm.pastDays)
                    ListTile(
                      title: Text(
                        formatDate(day),
                        style: const TextStyle(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      trailing: m.attackedOn(day)
                          ? Text(
                              '체력 -1',
                              style: AppTypography.bodyStrong.copyWith(
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              day == vm.today ? '아직' : '못 깎음',
                              style: AppTypography.callout.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                    ),
                ],
              ),
          ],
        ),
      },
      bottomNavigationBar: switch (vm.monster) {
        final m? when m.isActive => BottomActionBar(
          children: [
            Expanded(
              child: FilledButton.tonal(
                style: destructiveTextButtonStyle,
                onPressed: vm.ending ? null : () => end(m),
                child: const Text('처방 끝내기'),
              ),
            ),
          ],
        ),
        _ => null,
      },
    );
  }
}
