import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/photo_picker_service.dart';
import '../../data/services/prescription_scanner.dart';
import '../common/theme.dart';
import '../common/widgets.dart';

/// 처방 등록을 어떻게 시작할지 고른다: 처방전 찍기·올리기 또는 직접 입력 (상황 A · 3쪽).
///
/// 처방전을 고르면 읽은 초안을 처방 등록 화면에 넘긴다. 사진은 기기 밖으로 보내지 않는다.
/// 웹은 누른 순간에 사진 창을 열어야 막히지 않아서, 시트를 닫는 탭 처리 안에서 바로 연다.
void startPrescription(BuildContext context) {
  final picker = context.read<PhotoPickerService>();
  final scanner = context.read<PrescriptionScanner>();
  final messenger = ScaffoldMessenger.of(context);

  Future<void> scan(PhotoSource source) async {
    try {
      final photo = await picker.pick(source);
      if (photo == null || !context.mounted) return;
      final read = await _withProgress(context, scanner.scan(photo));
      if (!context.mounted) return;
      if (read.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('처방전에서 약을 읽지 못했어요. 직접 입력해 주세요.')),
        );
        return;
      }
      context.push('/medications/prescriptions/new', extra: read);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('처방전을 읽지 못했어요. 직접 입력해 주세요.')),
      );
    }
  }

  showModalBottomSheet<void>(
    context: context,
    // 탭 화면에서 열어도 아래 바와 기록하기 버튼 위에 뜨게 한다.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('처방 등록'),
          for (final (icon, title, subtitle, onTap) in [
            (
              Icons.document_scanner_rounded,
              '처방전 찍기',
              '약 이름, 기간, 하루 횟수를 읽어 와요',
              () => scan(PhotoSource.camera),
            ),
            (
              Icons.photo_library_rounded,
              '처방전 사진 올리기',
              '찍어 둔 처방전이나 약봉투 사진',
              () => scan(PhotoSource.gallery),
            ),
            (
              Icons.edit_rounded,
              '직접 입력',
              '약과 기간, 복용 시간을 하나씩 넣어요',
              () => context.push('/medications/prescriptions/new'),
            ),
          ])
            ListTile(
              leading: Icon(icon, color: AppColors.primary),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () {
                Navigator.pop(sheet);
                onTap();
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Text(
              '읽은 내용은 초안이라 확인하고 고친 뒤 등록해요. 처방전 사진은 기기 밖으로 보내지 않아요.',
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

/// [work]가 끝날 때까지 "처방전을 읽는 중"을 띄운다.
Future<T> _withProgress<T>(BuildContext context, Future<T> work) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text('처방전을 읽는 중')),
          ],
        ),
      ),
    ),
  );
  try {
    return await work;
  } finally {
    navigator.pop();
  }
}
