import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/cosmetic.dart';
import '../../utils/monster_look.dart';
import '../../utils/time_format.dart';
import '../common/cosmetic_widgets.dart';
import '../common/creature_art.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'collection_view_model.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CollectionViewModel>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('컬렉션'),
        actionsPadding: EdgeInsets.only(right: gutterOf(context) - 12),
        actions: [
          TextButton(
            onPressed: () => context.push('/draw'),
            child: const Text('뽑기'),
          ),
        ],
      ),
      body: switch (vm) {
        CollectionViewModel(loading: true) => const LoadingState(),
        _ => ListView(
          padding: pagePadding(context, top: AppSpacing.md),
          children: [
            Center(
              child: CharacterWithPet(
                stageExp: vm.growth.exp,
                skinId: vm.equipment.skin?.id,
                accessoryId: vm.equipment.accessory?.id,
                pet: vm.pet == null
                    ? null
                    : (
                        vm.pet!.prescription.id,
                        vm.looks[vm.pet!.prescription.id],
                      ),
                size: 140,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '아이템을 누르면 장착하고, 다시 누르면 빼요',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
            for (final slot in CosmeticSlot.values) ...[
              SectionLabel(slot.label),
              _CosmeticGrid(
                items: [
                  for (final c in cosmetics)
                    if (c.slot == slot) c,
                ],
                owned: vm.owned,
                isEquipped: vm.isEquipped,
                onTap: vm.toggle,
              ),
            ],
            const SectionLabel('펫'),
            if (vm.defeated.isEmpty)
              Text(
                '몬스터를 퇴치하면 펫이 돼요',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in vm.defeated)
                    _Tile(
                      selected: vm.pet?.prescription.id == m.prescription.id,
                      label: monsterName(vm.looks[m.prescription.id]),
                      onTap: () => vm.togglePet(m),
                      child: MonsterArt(
                        body: monsterBodyOf(
                          m.prescription.id,
                          vm.looks[m.prescription.id],
                        ),
                        color: monsterColor(vm.looks[m.prescription.id]?.color),
                        size: 56,
                        friendly: true,
                      ),
                    ),
                ],
              ),
            const SectionLabel('퇴치 기록'),
            if (vm.defeated.isEmpty)
              Text(
                '아직 퇴치한 몬스터가 없어요',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              )
            else
              GroupCard(
                children: [
                  for (final m in vm.defeated.reversed)
                    ListTile(
                      leading: MonsterArt(
                        body: monsterBodyOf(
                          m.prescription.id,
                          vm.looks[m.prescription.id],
                        ),
                        color: monsterColor(vm.looks[m.prescription.id]?.color),
                        size: 40,
                        defeated: true,
                      ),
                      title: Text(monsterName(vm.looks[m.prescription.id])),
                      subtitle: Text(
                        '${formatDate(m.prescription.startDate)} ~ '
                        '${formatDate(m.defeatedOn!)} · ${m.maxHp}일',
                        style: const TextStyle(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      },
    );
  }
}

class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({
    required this.items,
    required this.owned,
    required this.isEquipped,
    required this.onTap,
  });

  final List<Cosmetic> items;
  final Map<String, ({Cosmetic cosmetic, int count, DateTime firstObtained})>
  owned;
  final bool Function(Cosmetic) isEquipped;
  final void Function(Cosmetic) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final c in items)
          if (owned[c.id] case final o?)
            _Tile(
              selected: isEquipped(c),
              label: o.count > 1 ? '${c.name} ×${o.count}' : c.name,
              grade: c.grade,
              onTap: () => onTap(c),
              child: CosmeticPreview(cosmetic: c, size: 56),
            )
          else
            _Tile(
              selected: false,
              label: '아직 없음',
              grade: c.grade,
              child: const SizedBox.square(
                dimension: 56,
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkDisabled,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// 컬렉션 한 칸. 장착한 것은 바이올렛 테두리.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.label,
    required this.child,
    this.grade,
    this.onTap,
  });

  final bool selected;
  final String label;
  final Widget child;
  final Grade? grade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: onTap != null,
      label: [label, ?grade?.label, if (selected) '장착 중'].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          child: SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                children: [
                  child,
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                  if (grade != null) ...[
                    const SizedBox(height: 2),
                    GradeBadge(grade!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
