import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../data/services/photo_picker_service.dart';
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

    void showResult(Uint8List? photo) {
      if (photo != null && context.mounted) {
        context.push('/result', extra: photo);
      }
    }

    Future<void> pickPhoto(PhotoSource source) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        showResult(await vm.pickPhoto(source));
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              source == PhotoSource.camera
                  ? '카메라를 열 수 없습니다. 사진 올리기를 써 주세요.'
                  : '사진을 열 수 없습니다',
            ),
          ),
        );
      }
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
        HomeViewModel(summary: DaySummary(slots: [], unscheduled: [])) =>
          _Empty(
            message:
                '오늘 기록이 없습니다.\n알약 사진을 찍거나 올리면 인식한 약이 바로 기록됩니다.\n\n'
                '단색 배경 위에 알약끼리 떨어지게 놓고 바로 위에서 찍어 주세요.',
            action: Column(
              children: [
                TextButton(
                  onPressed: () async => showResult(await vm.loadSamplePhoto()),
                  child: const Text('샘플 사진으로 해 보기'),
                ),
                TextButton(
                  onPressed: () => context.push('/medications'),
                  child: const Text('복용 시간 정하기'),
                ),
              ],
            ),
          ),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 16),
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
                child: Text(
                  vm.summary.slots.isEmpty ? '오늘 기록' : '일정 외 기록',
                  style: textTheme.titleMedium,
                ),
              ),
              for (final record in vm.summary.unscheduled)
                ListTile(
                  leading: Icon(
                    record.source == IntakeSource.camera
                        ? Icons.photo
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: vm.picking
                      ? null
                      : () => pickPhoto(PhotoSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('사진 찍기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: vm.picking
                      ? null
                      : () => pickPhoto(PhotoSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('사진 올리기'),
                ),
              ),
            ],
          ),
        ),
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
