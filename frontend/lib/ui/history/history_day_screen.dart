import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'history_day_view_model.dart';

class HistoryDayScreen extends StatelessWidget {
  const HistoryDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryDayViewModel>();

    Future<void> delete(HistoryEntry entry) async {
      final ok = await confirm(
        context,
        message:
            '${formatTime(entry.record.takenAt)} ${entry.name} ${entry.record.count}정 기록을 지울까요?',
        action: '삭제',
        destructive: true,
      );
      if (ok) await vm.delete(entry);
    }

    return Scaffold(
      appBar: AppBar(title: Text(formatDate(vm.day))),
      body: switch (vm) {
        HistoryDayViewModel(loading: true) => const LoadingState(),
        HistoryDayViewModel(entries: []) => const EmptyState(
          icon: Icons.event_busy_rounded,
          title: '이날은 복용 기록이 없습니다',
        ),
        _ => ListView(
          padding: pagePadding(context),
          children: [
            GroupCard(
              children: [
                for (final entry in vm.entries)
                  ListTile(
                    leading: _Thumbnail(entry: entry),
                    title: Text(entry.name),
                    subtitle: Text(
                      '${formatTime(entry.record.takenAt)} · '
                      '${entry.record.source == IntakeSource.camera ? '사진' : '직접 기록'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.sm,
                      children: [
                        Text(
                          '${entry.record.count}정',
                          style: AppTypography.bodyStrong.copyWith(
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                        IconButton(
                          tooltip: '기록 삭제',
                          color: AppColors.error,
                          onPressed: () => delete(entry),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
      child: Icon(
        entry.record.photoPath == null
            ? Icons.edit_rounded
            : Icons.broken_image_rounded,
        color: AppColors.inkMuted,
      ),
    );
    final photo = entry.photo;
    if (photo == null) return placeholder;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          backgroundColor: AppColors.surfacePhoto,
          child: Image.memory(photo),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.memory(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 144,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
