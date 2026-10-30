import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/pill_label.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
import 'medication_edit_view_model.dart';

class MedicationEditScreen extends StatelessWidget {
  const MedicationEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationEditViewModel>();
    final textTheme = Theme.of(context).textTheme;

    Future<void> pickLabel() async {
      final label = await showModalBottomSheet<PillLabel>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LabelSearchSheet(labels: vm.availableLabels),
      );
      if (label != null) vm.selectLabel(label);
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
        actions: [
          if (!vm.isNew && !vm.loading && !vm.notFound)
            IconButton(
              tooltip: '약 삭제',
              onPressed: vm.saving ? null : delete,
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: switch (vm) {
        MedicationEditViewModel(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        MedicationEditViewModel(notFound: true) => const Center(
          child: Text('지워진 약입니다'),
        ),
        _ => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('약', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              child: ListTile(
                title: Text(vm.name.isEmpty ? '약을 고르세요' : vm.name),
                subtitle: vm.name.isEmpty
                    ? null
                    : Text(
                        vm.categoryId == null
                            ? '직접 입력 · 사진으로 인식되지 않아 직접 기록만 됩니다'
                            : '사진으로 인식되는 약',
                      ),
                trailing: const Icon(Icons.search),
                onTap: pickLabel,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: enterCustomName,
                child: const Text('목록에 없는 약 직접 입력'),
              ),
            ),
            const SizedBox(height: 16),
            Text('1회 수량', style: textTheme.titleMedium),
            Row(
              children: [
                IconButton(
                  tooltip: '1정 줄이기',
                  onPressed: vm.dosePerTake > 1
                      ? () => vm.setDose(vm.dosePerTake - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${vm.dosePerTake}정', style: textTheme.titleLarge),
                IconButton(
                  tooltip: '1정 늘리기',
                  onPressed: () => vm.setDose(vm.dosePerTake + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('복용 시간', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in vm.times)
                  InputChip(
                    label: Text(formatMinuteOfDay(time)),
                    deleteButtonTooltipMessage:
                        '${formatMinuteOfDay(time)} 지우기',
                    onDeleted: () => vm.removeTime(time),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('시간 추가'),
                  onPressed: addTime,
                ),
              ],
            ),
          ],
        ),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: vm.canSave ? save : null,
            child: const Text('저장'),
          ),
        ),
      ),
    );
  }
}

class _LabelSearchSheet extends StatefulWidget {
  const _LabelSearchSheet({required this.labels});

  final List<PillLabel> labels;

  @override
  State<_LabelSearchSheet> createState() => _LabelSearchSheetState();
}

class _LabelSearchSheetState extends State<_LabelSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final l in widget.labels)
        if (l.name.toLowerCase().contains(_query.toLowerCase())) l,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '약 이름 검색',
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('찾는 약이 없습니다'))
                  : ListView(
                      children: [
                        for (final l in matches)
                          ListTile(
                            title: Text(l.name),
                            onTap: () => Navigator.pop(context, l),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
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
