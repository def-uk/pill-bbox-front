import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/monster_look.dart';
import '../common/creature_art.dart';
import '../common/motion.dart';
import '../common/stage_widgets.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'monster_view_model.dart';

/// 처방을 등록하면 나타나는 새 몬스터 (상황 A · 4쪽).
///
/// 생김새는 처방 속 약의 색·모양으로 추천하고, 사용자가 다른 생김새로 바꿀 수 있다.
/// 병명과 약 이름은 쓰지 않는다 (docs/MVP.md 3장).
class MonsterIntroScreen extends StatelessWidget {
  const MonsterIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MonsterViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final m = vm.monster;

    return Scaffold(
      appBar: AppBar(
        title: const Text('새 몬스터'),
        automaticallyImplyLeading: false,
      ),
      body: switch (vm) {
        MonsterViewModel(loading: true) => const LoadingState(),
        MonsterViewModel(monster: null) => const EmptyState(
          icon: Icons.pest_control_rounded,
          title: '지워진 처방입니다',
        ),
        _ => ListView(
          padding: pagePadding(context, top: AppSpacing.lg),
          children: [
            Center(
              child: _PopIn(
                key: ValueKey(vm.look),
                child: MonsterArt(
                  body: monsterBodyOf(m!.prescription.id, vm.look),
                  color: monsterColor(vm.look?.color),
                  size: 180,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              vm.name,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              switch (vm.look) {
                null => '약 생김새를 알면 그 색으로 바뀌어요',
                final look when presetMonsterLooks.contains(look) =>
                  '고른 모습이에요. 누를 때마다 바뀌어요',
                _ => '처방 속 약의 색·모양으로 만들었어요',
              },
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            GroupCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('체력', style: textTheme.titleMedium),
                          const Spacer(),
                          Text(
                            '${m.hp} / ${m.maxHp}',
                            style: AppTypography.headline.copyWith(
                              color: hpColor,
                              fontFeatures: AppTypography.tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      HpBar(hp: m.hp, maxHp: m.maxHp, height: 14),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '처방 ${m.maxHp}일 · 하루치를 사진으로 채우면 1칸',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton.icon(
                onPressed: vm.lookChoices.isEmpty ? null : vm.nextLook,
                icon: const Icon(Icons.autorenew_rounded),
                label: const Text('다른 몬스터로 바꾸기'),
              ),
            ),
          ],
        ),
      },
      bottomNavigationBar: m == null
          ? null
          : BottomActionBar(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.pop(),
                    child: Text('${m.maxHp}일 동안 물리치기'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 몬스터가 톡 튀어나온다. 애니메이션을 줄였으면 바로 보인다.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!motionOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
