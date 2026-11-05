import 'package:flutter/material.dart';

import '../../data/models/medication.dart';
import 'theme.dart';
import 'widgets.dart';

/// 종류마다 고를 때 보여 주는 설명.
String kindDescription(MedicationKind kind) => switch (kind) {
  MedicationKind.supplement => '비타민, 유산균처럼 매일 챙겨 먹는 것',
  MedicationKind.prescription => '병원에서 처방받아 기간 동안 먹는 약',
  MedicationKind.asNeeded => '진통제처럼 필요할 때만 먹는 약 · 기록만 남아요',
};

/// 약 종류를 고르는 시트. 그냥 닫으면 null.
Future<MedicationKind?> pickKind(
  BuildContext context, {
  required String title,
  MedicationKind? current,
}) => showModalBottomSheet<MedicationKind>(
  context: context,
  // 탭 화면에서 열어도 아래 바와 기록하기 버튼 위에 뜨게 한다.
  useRootNavigator: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(title),
        for (final kind in MedicationKind.values)
          ListTile(
            title: Text(kind.label),
            subtitle: Text(kindDescription(kind)),
            trailing: kind == current
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: () => Navigator.pop(sheet, kind),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    ),
  ),
);

/// 약 종류를 고르는 세 칸 버튼.
class KindSelector extends StatelessWidget {
  const KindSelector({super.key, required this.kind, required this.onChanged});

  final MedicationKind? kind;
  final ValueChanged<MedicationKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MedicationKind>(
      segments: [
        for (final k in MedicationKind.values)
          ButtonSegment(
            value: k,
            label: Text(k == MedicationKind.asNeeded ? '필요할 때' : k.label),
          ),
      ],
      selected: {?kind},
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) onChanged(selected.single);
      },
    );
  }
}
