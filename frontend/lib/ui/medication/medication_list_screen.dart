import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/time_format.dart';
import '../common/widgets.dart';
import 'medication_list_view_model.dart';

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationListViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('약 관리')),
      body: switch (vm) {
        MedicationListViewModel(loading: true) => const LoadingState(),
        MedicationListViewModel(medications: []) => const EmptyState(
          icon: Icons.medication_rounded,
          title: '등록한 약이 없습니다',
          message: '약과 복용 시간을 등록하면 오늘 화면에 시간대별로 보여요.',
        ),
        _ => ListView(
          padding: pagePadding(context, bottom: 120),
          children: [
            GroupCard(
              children: [
                for (final m in vm.medications)
                  ListTile(
                    title: Text(m.name),
                    subtitle: Text(
                      [
                        '1회 ${m.dosePerTake}정',
                        if (m.times.isEmpty)
                          '복용 시간 없음'
                        else
                          m.times.map(formatMinuteOfDay).join(', '),
                        if (m.categoryId == null) '직접 기록만',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/medications/${m.id}'),
                  ),
              ],
            ),
          ],
        ),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medications/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('약 등록'),
      ),
    );
  }
}
