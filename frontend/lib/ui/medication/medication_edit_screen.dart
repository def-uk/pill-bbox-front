import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/drug_info.dart';
import '../../data/models/pill_label.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import '../common/drug_widgets.dart';
import '../common/widgets.dart';
import 'medication_edit_view_model.dart';

class MedicationEditScreen extends StatelessWidget {
  const MedicationEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationEditViewModel>();
    final textTheme = Theme.of(context).textTheme;

    Future<void> pickLabel() async {
      final picked = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LabelSearchSheet(
          labels: vm.availableLabels,
          searchDrugs: vm.canSearchDrugs ? vm.searchDrugs : null,
          drugImageUrl: vm.drugImageUrl,
        ),
      );
      switch (picked) {
        case PillLabel label:
          vm.selectLabel(label);
        case DrugSummary drug:
          vm.selectDrug(drug);
      }
    }

    Future<void> enterCustomName() async {
      final name = await showDialog<String>(
        context: context,
        builder: (_) =>
            _CustomNameDialog(initial: vm.categoryId == null ? vm.name : ''),
      );
      if (name != null && name.trim().isNotEmpty) vm.setCustomName(name);
    }

    Future<void> addTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: vm.suggestedTime ~/ 60,
          minute: vm.suggestedTime % 60,
        ),
      );
      if (picked != null) vm.addTime(picked.hour * 60 + picked.minute);
    }

    Future<void> save() async {
      if (await vm.save() && context.mounted) context.pop();
    }

    Future<void> delete() async {
      final ok = await confirm(
        context,
        message: '${vm.name}과 이 약의 복용 기록을 모두 지울까요?',
        action: '삭제',
        destructive: true,
      );
      if (!ok) return;
      await vm.delete();
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isNew ? '약 등록' : '약 수정'),
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
        MedicationEditViewModel(loading: true) => const LoadingState(),
        MedicationEditViewModel(notFound: true) => const EmptyState(
          icon: Icons.medication_rounded,
          title: '지워진 약입니다',
        ),
        _ => ListView(
          padding: pagePadding(context),
          children: [
            const SectionLabel('약', first: true),
            GroupCard(
              children: [
                ListTile(
                  title: Text(
                    vm.name.isEmpty ? '약을 고르세요' : vm.name,
                    style: vm.name.isEmpty
                        ? textTheme.titleMedium?.copyWith(
                            color: AppColors.inkMuted,
                          )
                        : null,
                  ),
                  subtitle: vm.name.isEmpty
                      ? null
                      : Text(switch (vm) {
                          MedicationEditViewModel(categoryId: _?) =>
                            '사진으로 인식되는 약',
                          MedicationEditViewModel(fromMfds: true) =>
                            '식약처 의약품 · 사진으로 인식되지 않아 직접 기록만 됩니다',
                          _ => '직접 입력 · 사진으로 인식되지 않아 직접 기록만 됩니다',
                        }),
                  trailing: const Icon(Icons.search_rounded),
                  onTap: pickLabel,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: enterCustomName,
                child: const Text('목록에 없는 약 직접 입력'),
              ),
            ),
            if (vm.canOpenDrugInfo)
              GroupCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('약 정보'),
                    subtitle: const Text('효능, 주의사항, 생김새 · 식약처'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        context.push('/medications/${vm.medicationId}/info'),
                  ),
                ],
              ),
            const SectionLabel('1회 수량'),
            GroupCard(
              children: [
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
                        child: Text('한 번에 먹는 개수', style: textTheme.bodyLarge),
                      ),
                      CountStepper(
                        label: '${vm.dosePerTake}정',
                        decrementTooltip: '1정 줄이기',
                        incrementTooltip: '1정 늘리기',
                        onDecrement: vm.dosePerTake > 1
                            ? () => vm.setDose(vm.dosePerTake - 1)
                            : null,
                        onIncrement: () => vm.setDose(vm.dosePerTake + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionLabel('복용 시간'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final time in vm.times)
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
                    onDeleted: () => vm.removeTime(time),
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
                  onPressed: addTime,
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
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 모델이 아는 약에서 고르고, 없으면 식약처 의약품에서 찾는다.
/// [PillLabel]이나 [DrugSummary]를 돌려준다.
class _LabelSearchSheet extends StatefulWidget {
  const _LabelSearchSheet({
    required this.labels,
    required this.searchDrugs,
    required this.drugImageUrl,
  });

  final List<PillLabel> labels;

  /// null이면 식약처에서 찾지 않는다 (서버 없는 빌드).
  final Future<DrugPage> Function(String query)? searchDrugs;
  final String Function(String itemSeq) drugImageUrl;

  @override
  State<_LabelSearchSheet> createState() => _LabelSearchSheetState();
}

class _LabelSearchSheetState extends State<_LabelSearchSheet> {
  String _query = '';

  /// 식약처에서 찾은 이름과 결과. 이름을 바꾸면 다시 찾을 때까지 숨긴다.
  String? _drugQuery;
  Future<DrugPage>? _drugResults;

  /// 식약처는 두 글자부터 찾는다. 한 글자는 결과가 너무 많다.
  bool get _canSearchDrugs =>
      widget.searchDrugs != null && _query.characters.length >= 2;

  void _searchDrugs() {
    if (!_canSearchDrugs) return;
    setState(() {
      _drugQuery = _query;
      _drugResults = widget.searchDrugs!(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final l in widget.labels)
        if (l.name.toLowerCase().contains(_query.toLowerCase())) l,
    ];
    final searching = widget.searchDrugs != null;
    final showDrugs = _drugResults != null && _drugQuery == _query;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('약 고르기'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: SearchField(
                autofocus: true,
                hintText: '약 이름 검색',
                onChanged: (value) => setState(() => _query = value.trim()),
                onSubmitted: searching ? (_) => _searchDrugs() : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: matches.isEmpty && !searching
                  ? const Center(child: Text('찾는 약이 없습니다'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      children: [
                        if (searching && matches.isNotEmpty)
                          const SheetSectionLabel('사진으로 인식되는 약'),
                        for (final l in matches)
                          ListTile(
                            title: Text(l.name),
                            onTap: () => Navigator.pop(context, l),
                          ),
                        if (searching) ...[
                          const SheetSectionLabel('식약처 의약품'),
                          if (showDrugs)
                            _DrugResults(
                              results: _drugResults!,
                              imageUrl: widget.drugImageUrl,
                              onRetry: _searchDrugs,
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.travel_explore_rounded),
                              title: Text(
                                _canSearchDrugs
                                    ? '식약처에서 \'$_query\' 찾기'
                                    : '식약처에서 찾기',
                              ),
                              subtitle: _canSearchDrugs
                                  ? null
                                  : const Text('이름을 두 글자 넘게 넣어 주세요'),
                              enabled: _canSearchDrugs,
                              onTap: _searchDrugs,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrugResults extends StatelessWidget {
  const _DrugResults({
    required this.results,
    required this.imageUrl,
    required this.onRetry,
  });

  final Future<DrugPage> results;
  final String Function(String itemSeq) imageUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: results,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline_rounded),
            title: Text('${snapshot.error}'),
            trailing: TextButton(onPressed: onRetry, child: const Text('다시')),
          );
        }
        final page = snapshot.data;
        if (page == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (page.items.isEmpty) {
          return const ListTile(title: Text('식약처에도 없는 약입니다'));
        }
        return Column(
          children: [
            for (final drug in page.items)
              DrugTile(
                drug: drug,
                imageUrl: imageUrl,
                onTap: () => Navigator.pop(context, drug),
              ),
            if (page.total > page.items.length)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  '${page.total}개 중 ${page.items.length}개. 이름을 더 자세히 넣어 보세요',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CustomNameDialog extends StatefulWidget {
  const _CustomNameDialog({required this.initial});

  final String initial;

  @override
  State<_CustomNameDialog> createState() => _CustomNameDialogState();
}

class _CustomNameDialogState extends State<_CustomNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('약 이름'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          helperText: '사진으로 인식되지 않아 직접 기록만 할 수 있습니다',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
