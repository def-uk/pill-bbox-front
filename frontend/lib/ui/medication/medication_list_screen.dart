import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/time_format.dart';
import 'medication_list_view_model.dart';

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationListViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('약 관리')),
      body: switch (vm) {
        MedicationListViewModel(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        MedicationListViewModel(medications: []) => const Center(
          child: Text('등록한 약이 없습니다'),
        ),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 96),
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
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/medications/${m.id}'),
              ),
          ],
        ),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medications/new'),
        icon: const Icon(Icons.add),
        label: const Text('약 등록'),
      ),
    );
  }
}
