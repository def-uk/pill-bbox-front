import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../utils/time_format.dart';
import '../common/medication_picker.dart';
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
        HistoryDayViewModel(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        HistoryDayViewModel(entries: []) => const Center(
          child: Text('이날은 복용 기록이 없습니다'),
        ),
        _ => ListView(
          children: [
            for (final entry in vm.entries)
              ListTile(
                leading: _Thumbnail(entry: entry),
                title: Text(entry.name),
                subtitle: Text(
                  '${formatTime(entry.record.takenAt)} · '
                  '${entry.record.source == IntakeSource.camera ? '촬영' : '직접 기록'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${entry.record.count}정'),
                    IconButton(
                      tooltip: '기록 삭제',
                      onPressed: () => delete(entry),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
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
    final placeholder = SizedBox.square(
      dimension: size,
      child: Icon(
        entry.record.photoPath == null
            ? Icons.edit
            : Icons.broken_image_outlined,
      ),
    );
    final photo = entry.photo;
    if (photo == null) return placeholder;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(child: Image.memory(photo)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
