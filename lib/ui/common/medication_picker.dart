import 'package:flutter/material.dart';

import '../../data/models/medication.dart';

/// 등록한 약 중 하나를 고르는 시트. 고르지 않으면 null.
Future<Medication?> showMedicationPicker(
  BuildContext context, {
  required String title,
  required List<Medication> medications,
}) {
  return showModalBottomSheet<Medication>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (medications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('등록한 약이 없습니다. 약 관리에서 먼저 등록해 주세요.'),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in medications)
                    ListTile(
                      title: Text(m.name),
                      subtitle: Text('1회 ${m.dosePerTake}정'),
                      onTap: () => Navigator.pop(context, m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
