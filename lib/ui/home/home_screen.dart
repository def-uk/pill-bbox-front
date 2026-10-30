import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final textTheme = Theme.of(context).textTheme;

    Future<void> markTaken(DoseSlot slot) async {
      final ok = await confirm(
        context,
        message: '${slot.medication.name} ${slot.remaining}정을 복용한 것으로 기록할까요?',
        action: '기록',
      );
      if (ok) await vm.markTaken(slot);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('오늘 · ${formatDate(vm.today)}'),
        actions: [
          IconButton(
            tooltip: '기록',
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: '약 관리',
            onPressed: () => context.push('/medications'),
            icon: const Icon(Icons.medication),
          ),
        ],
      ),
      body: switch (vm) {
        HomeViewModel(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        HomeViewModel(medications: []) => _Empty(
          message: '복용할 약을 먼저 등록해 주세요',
          action: FilledButton(
            onPressed: () => context.push('/medications/new'),
            child: const Text('약 등록'),
          ),
        ),
        HomeViewModel(summary: DaySummary(slots: [], unscheduled: [])) =>
          const _Empty(message: '등록한 약에 복용 시간이 없습니다.\n약 관리에서 복용 시간을 넣어 주세요.'),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final (time, slots) in vm.slotsByTime) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  formatMinuteOfDay(time),
                  style: textTheme.titleMedium,
                ),
              ),
              for (final slot in slots)
                ListTile(
                  title: Text(slot.medication.name),
                  subtitle: Text('1회 ${slot.medication.dosePerTake}정'),
                  trailing: _SlotStatus(slot: slot),
                  onTap: slot.isDone ? null : () => markTaken(slot),
                ),
            ],
            if (vm.summary.unscheduled.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('일정 외 기록', style: textTheme.titleMedium),
              ),
              for (final record in vm.summary.unscheduled)
                ListTile(
                  leading: Icon(
                    record.source == IntakeSource.camera
                        ? Icons.photo_camera
                        : Icons.edit,
                  ),
                  title: Text(vm.nameOf(record.medicationId)),
                  subtitle: Text(formatTime(record.takenAt)),
                  trailing: Text('${record.count}정'),
                ),
            ],
          ],
        ),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        icon: const Icon(Icons.photo_camera),
        label: const Text('촬영'),
      ),
    );
  }
}

class _SlotStatus extends StatelessWidget {
  const _SlotStatus({required this.slot});

  final DoseSlot slot;

  @override
  Widget build(BuildContext context) {
    final dose = slot.medication.dosePerTake;
    if (slot.isDone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          const Text('완료'),
        ],
      );
    }
    if (slot.taken > 0) {
      return Text(
        '$dose정 중 ${slot.taken}정',
        style: const TextStyle(color: reviewColor),
      );
    }
    return Text(
      '예정',
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
