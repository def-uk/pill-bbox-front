import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/medication.dart';
import '../../data/models/prescription.dart';
import '../../utils/time_format.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'medication_list_view_model.dart';

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MedicationListViewModel>();
    final addPrescription = ListTile(
      leading: const Icon(Icons.add_rounded, color: AppColors.primary),
      title: const Text('처방 등록', style: TextStyle(color: AppColors.primary)),
      subtitle: const Text('병원에서 받은 약과 기간, 복용 시간'),
      onTap: () => context.push('/medications/prescriptions/new'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('약 관리')),
      body: switch (vm) {
        MedicationListViewModel(loading: true) => const LoadingState(),
        MedicationListViewModel(medications: [], prescriptions: []) =>
          EmptyState(
            icon: Icons.medication_rounded,
            title: '등록한 약이 없습니다',
            message: '약과 복용 시간을 등록하면 오늘 화면에 시간대별로 보여요.',
            action: FilledButton.tonal(
              style: tonalButtonStyle,
              onPressed: () => context.push('/medications/prescriptions/new'),
              child: const Text('처방 등록'),
            ),
          ),
        _ => ListView(
          padding: pagePadding(context, bottom: 120),
          children: [
            const SectionLabel('처방', first: true),
            GroupCard(
              children: [
                for (final p in vm.prescriptions)
                  _PrescriptionTile(
                    prescription: p,
                    names: [for (final i in p.items) vm.nameOf(i.medicationId)],
                    today: vm.today,
                  ),
                addPrescription,
              ],
            ),
            if (vm.medications.isNotEmpty) ...[
              const SectionLabel('약'),
              GroupCard(
                children: [
                  for (final m in vm.medications)
                    ListTile(
                      title: Text(m.name),
                      subtitle: Text(
                        [
                          m.kind?.label ?? '종류 없음',
                          '1회 ${m.dosePerTake}정',
                          if (m.times.isNotEmpty)
                            m.times.map(formatMinuteOfDay).join(', ')
                          else if (m.kind != MedicationKind.prescription)
                            '복용 시간 없음',
                          if (m.categoryId == null) '직접 기록만',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/medications/${m.id}'),
                    ),
                ],
              ),
            ],
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

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.names,
    required this.today,
  });

  final Prescription prescription;
  final List<String> names;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final state = switch (p) {
      Prescription(status: PrescriptionStatus.active) when p.isOverOn(today) =>
        '기간 끝남',
      Prescription(status: PrescriptionStatus.active) => null,
      _ => p.status.label,
    };
    return ListTile(
      title: Text(
        names.length <= 2
            ? names.join(', ')
            : '${names.first} 외 ${names.length - 1}개',
      ),
      subtitle: Text(
        ['${formatDate(p.startDate)}부터 ${p.days}일', ?state].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/medications/prescriptions/${p.id}'),
    );
  }
}
