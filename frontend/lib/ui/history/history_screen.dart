import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/time_format.dart';
import '../common/widgets.dart';
import 'history_view_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: switch (vm) {
        HistoryViewModel(loading: true) => const LoadingState(),
        HistoryViewModel(days: []) => const EmptyState(
          icon: Icons.calendar_month_rounded,
          title: '아직 복용 기록이 없습니다',
          message: '알약 사진으로 기록하면 날짜별로 모아 보여요.',
        ),
        _ => ListView(
          padding: pagePadding(context),
          children: [
            GroupCard(
              children: [
                for (final day in vm.days)
                  ListTile(
                    title: Text(formatDate(day)),
                    subtitle: Text('${day.year}년'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/history/${dateKey(day)}'),
                  ),
              ],
            ),
          ],
        ),
      },
    );
  }
}
