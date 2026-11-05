import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/time_format.dart';
import '../common/drug_search_sheet.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'prescription_edit_view_model.dart';

class PrescriptionEditScreen extends StatelessWidget {
  const PrescriptionEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PrescriptionEditViewModel>();
    final textTheme = Theme.of(context).textTheme;

    Future<void> editItem(int? index, PrescriptionItemDraft draft) async {
      final edited = await showModalBottomSheet<PrescriptionItemDraft>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ItemSheet(draft: draft),
      );
      if (edited != null) vm.putItem(index, edited);
    }

    Future<void> addItem() async {
      final picked = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DrugSearchSheet(
          medications: vm.pickableMedications,
          labels: vm.availableLabels,
          searchDrugs: vm.canSearchDrugs ? vm.searchDrugs : null,
          drugImageUrl: vm.drugImageUrl,
          allowCustom: true,
        ),
      );
      if (picked != null && context.mounted) {
        await editItem(null, vm.draftFor(picked));
      }
    }

    Future<void> pickStartDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: vm.startDate,
        firstDate: DateTime(vm.today.year - 1, vm.today.month, vm.today.day),
        lastDate: DateTime(vm.today.year + 1, vm.today.month, vm.today.day),
      );
      if (picked != null) vm.setStartDate(picked);
    }

    Future<void> save() async {
      if (!await vm.save() || !context.mounted) return;
      // 새 처방이면 새 몬스터를 보여 준다 (상황 A · 4쪽). 닫으면 약 관리로 돌아온다.
      if (vm.isNew && vm.savedId != null) {
        context.pushReplacement('/monsters/${vm.savedId}/new');
      } else {
        context.pop();
      }
    }

    Future<void> delete() async {
      final ok = await confirm(
        context,
        message: '이 처방을 지울까요? 약과 복용 기록은 남습니다.',
        action: '삭제',
        destructive: true,
      );
      if (!ok) return;
      await vm.delete();
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.fromScan
              ? '처방전 확인'
              : vm.isNew
              ? '처방 등록'
              : '처방 수정',
        ),
        actionsPadding: EdgeInsets.only(right: gutterOf(context) - 12),
        actions: [
          if (!vm.isNew && !vm.loading && !vm.notFound)
            TextButton(
              style: destructiveTextButtonStyle,
              onPressed: vm.saving ? null : delete,
              child: const Text('삭제'),
            ),
        ],
      ),
      body: switch (vm) {
        PrescriptionEditViewModel(loading: true) => const LoadingState(),
        PrescriptionEditViewModel(notFound: true) => const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: '지워진 처방입니다',
        ),
        _ => ListView(
          padding: pagePadding(context),
          children: [
            if (vm.fromScan) ...[
              const SizedBox(height: AppSpacing.xs),
              const _ScanNotice(),
            ],
            SectionLabel('처방받은 약', first: !vm.fromScan),
            GroupCard(
              children: [
                for (final (i, item) in vm.items.indexed)
                  ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      item.times.isEmpty
                          ? '1회 ${item.dosePerTake}정 · 복용 시간을 넣어 주세요'
                          : '1회 ${item.dosePerTake}정 · 하루 ${item.times.length}회 '
                                '(${item.times.map(formatMinuteOfDay).join(', ')})',
                      style: item.times.isEmpty
                          ? const TextStyle(color: reviewColor)
                          : null,
                    ),
                    trailing: IconButton(
                      tooltip: '${item.name} 빼기',
                      onPressed: () => vm.removeItem(i),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    onTap: () => editItem(i, item),
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    '약 추가',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  onTap: addItem,
                ),
              ],
            ),
            const SectionLabel('기간'),
            GroupCard(
              children: [
                ListTile(
                  title: const Text('시작일'),
                  trailing: Text(
                    formatDate(vm.startDate),
                    style: AppTypography.bodyStrong.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                  onTap: pickStartDate,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('처방 일수', style: textTheme.bodyLarge),
                            Text(
                              '${formatDate(vm.endDate)}까지',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.inkMuted,
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CountStepper(
                        label: '${vm.days}일',
                        decrementTooltip: '하루 줄이기',
                        incrementTooltip: '하루 늘리기',
                        onDecrement: vm.days > 1
                            ? () => vm.setDays(vm.days - 1)
                            : null,
                        onIncrement: () => vm.setDays(vm.days + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final d in PrescriptionEditViewModel.quickDays)
                  ChoiceChip(
                    label: Text('$d일'),
                    selected: vm.days == d,
                    onSelected: (_) => vm.setDays(d),
                  ),
              ],
            ),
          ],
        ),
      },
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: vm.canSave ? save : null,
              child: Text(vm.fromScan ? '확인하고 등록' : '저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 처방 속 약 하나의 1회 알 수와 회차 시간. 확인하면 고친 줄을 돌려준다.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.draft});

  final PrescriptionItemDraft draft;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late int _dose = widget.draft.dosePerTake;
  late List<int> _times = widget.draft.times;

  Future<void> _addTime() async {
    final suggested = _times.isEmpty
        ? 8 * 60
        : (_times.last + 4 * 60) % (24 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: suggested ~/ 60, minute: suggested % 60),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    if (_times.contains(minute)) return;
    setState(() => _times = [..._times, minute]..sort());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(widget.draft.name),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('1회 알 수', style: textTheme.bodyLarge)),
                  CountStepper(
                    label: '$_dose정',
                    decrementTooltip: '1정 줄이기',
                    incrementTooltip: '1정 늘리기',
                    onDecrement: _dose > 1
                        ? () => setState(() => _dose--)
                        : null,
                    onIncrement: () => setState(() => _dose++),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Text(
                _times.isEmpty ? '복용 시간' : '복용 시간 · 하루 ${_times.length}회',
                style: textTheme.bodyLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final time in _times)
                    InputChip(
                      label: Text(
                        formatMinuteOfDay(time),
                        style: const TextStyle(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 18),
                      deleteButtonTooltipMessage:
                          '${formatMinuteOfDay(time)} 지우기',
                      onDeleted: () =>
                          setState(() => _times = [..._times]..remove(time)),
                    ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.add_rounded,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      '시간 추가',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    onPressed: _addTime,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: FilledButton(
                onPressed: _times.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        widget.draft.copyWith(
                          dosePerTake: _dose,
                          times: _times,
                        ),
                      ),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 처방전에서 읽은 값은 초안이라 확인하고 고쳐야 한다는 안내.
class _ScanNotice extends StatelessWidget {
  const _ScanNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.reviewSoft,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.document_scanner_rounded, color: reviewColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '처방전에서 읽은 내용은 초안이에요. 약 이름, 기간, 복용 시간이 '
                '처방전과 다르면 눌러서 고친 뒤 등록해 주세요.',
                style: AppTypography.callout.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
