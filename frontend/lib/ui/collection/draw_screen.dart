import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/reward_calculator.dart';
import '../common/cosmetic_widgets.dart';
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
              _DrawResult(cosmetic: cosmetic, count: count),
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

class _DrawResult extends StatelessWidget {
  const _DrawResult({required this.cosmetic, required this.count});

  final Cosmetic cosmetic;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            CosmeticPreview(cosmetic: cosmetic, size: 120),
            const SizedBox(height: AppSpacing.xs),
            GradeBadge(cosmetic.grade),
            const SizedBox(height: AppSpacing.xxs),
            Text(cosmetic.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              count > 1
                  ? '이미 있는 아이템이에요 · $count개째'
                  : '새 ${cosmetic.slot.label}! 컬렉션에서 장착할 수 있어요',
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
