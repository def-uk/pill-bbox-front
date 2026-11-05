import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../data/models/medication.dart';
import '../../data/services/photo_picker_service.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/time_format.dart';
import '../common/kind_picker.dart';
import '../common/medication_picker.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    Future<void> markTaken(DoseSlot slot) async {
      final ok = await confirm(
        context,
        message: '${slot.medication.name} ${slot.remaining}정을 복용한 것으로 기록할까요?',
        action: '기록',
      );
      if (ok) await vm.markTaken(slot);
    }

    Future<void> chooseKind(Medication medication) async {
      final kind = await pickKind(
        context,
        title: '${medication.name}은(는) 어떤 약인가요?',
      );
      if (kind != null) await vm.setKind(medication, kind);
    }

    final kindPrompt = vm.untyped.isEmpty
        ? null
        : _KindPrompt(medications: vm.untyped, onTap: chooseKind);

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

    Future<void> exportExcel() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        if (await vm.exportExcel()) {
          messenger.showSnackBar(
            const SnackBar(content: Text('엑셀로 내보냈습니다. 사진은 들어가지 않습니다.')),
          );
        }
      } catch (_) {
        messenger.showSnackBar(const SnackBar(content: Text('내보내지 못했습니다')));
      }
    }

    // 파일 창은 메뉴를 누른 그 처리 안에서 연다(웹, 아래 chooseSource와 같은 까닭).
    Future<void> importExcel() async {
      final messenger = ScaffoldMessenger.of(context);
      String message;
      try {
        final summary = await vm.importExcel();
        if (summary == null) return;
        final (:medications, :records, :prescriptions, :skippedRows) = summary;
        message = medications == 0 && records == 0 && prescriptions == 0
            ? '새로 가져올 약이나 기록이 없습니다'
            : '약 $medications개, 기록 $records개'
                  '${prescriptions > 0 ? ', 처방 $prescriptions개' : ''}를 가져왔습니다';
        if (skippedRows > 0) message += ' · 읽지 못한 행 $skippedRows개';
      } on FormatException catch (e) {
        message = e.message;
      } catch (_) {
        message = '가져오지 못했습니다';
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    // 웹은 사용자가 누른 그 순간에 열어야 브라우저가 카메라·파일 창을 막지 않는다.
    // 그래서 시트를 닫는 것과 같은 탭 처리 안에서 바로 연다.
    void chooseSource() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('기록하기'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              child: Row(
                spacing: AppSpacing.sm,
                children: [
                  for (final (source, icon, label) in [
                    (PhotoSource.camera, Icons.photo_camera_rounded, '사진 찍기'),
                    (
                      PhotoSource.gallery,
                      Icons.photo_library_rounded,
                      '사진 올리기',
                    ),
                  ])
                    Expanded(
                      // 시트 안의 큰 선택지라 담는 모양(둥근 사각형)으로 둔다.
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(AppRadius.lg),
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheet);
                          pickPhoto(source);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 32),
                            const SizedBox(height: AppSpacing.xs),
                            Text(label),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final compact = MediaQuery.sizeOf(context).width < AppLayout.compact;

    return Scaffold(
      appBar: AppBar(
        title: Text('오늘 · ${formatDate(vm.today)}'),
        actionsPadding: EdgeInsets.only(right: gutterOf(context) - 4),
        actions: [
          IconButton(
            tooltip: '기록',
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: '약 관리',
            onPressed: () => context.push('/medications'),
            icon: const Icon(Icons.medication_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<void>(
            tooltip: '더 보기',
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (_) => [
              PopupMenuItem(onTap: exportExcel, child: const Text('엑셀로 내보내기')),
              PopupMenuItem(onTap: importExcel, child: const Text('엑셀에서 가져오기')),
            ],
          ),
        ],
      ),
      body: switch (vm) {
        HomeViewModel(loading: true) => const LoadingState(),
        HomeViewModel(isEmpty: true) => _EmptyGuide(
          header: kindPrompt,
          onTrySample: () async => showResult(await vm.loadSamplePhoto()),
          onSetSchedule: () => context.push('/medications'),
        ),
        _ => ListView(
          // 아래 떠 있는 기록하기 버튼에 마지막 카드가 가리지 않게 비워 둔다.
          padding: pagePadding(context, bottom: 120),
          children: [
            if (kindPrompt != null) ...[
              kindPrompt,
              const SizedBox(height: AppSpacing.xl),
            ],
            for (final (i, (time, slots)) in vm.slotsByTime.indexed) ...[
              // 시간대 카드 사이는 섹션처럼 32를 비워 덩어리로 읽히게 한다.
              if (i > 0) const SizedBox(height: AppSpacing.xl),
              _DoseCard(
                time: time,
                slots: slots,
                current: time == vm.currentTime,
                onTap: markTaken,
              ),
            ],
            if (vm.summary.unscheduled.isNotEmpty) ...[
              if (vm.summary.slots.isNotEmpty)
                const SizedBox(height: AppSpacing.xl),
              GroupCard(
                children: [
                  _CardHeader(
                    title: vm.summary.slots.isEmpty ? '오늘 기록' : '일정 외 기록',
                  ),
                  for (final record in vm.summary.unscheduled)
                    _Row(
                      leading: Icon(
                        record.source == IntakeSource.camera
                            ? Icons.photo_camera_rounded
                            : Icons.edit_rounded,
                        size: 22,
                        color: AppColors.inkMuted,
                      ),
                      title: vm.nameOf(record.medicationId),
                      subtitle: formatTime(record.takenAt),
                      trailing: Text(
                        '${record.count}정',
                        style: AppTypography.bodyStrong.copyWith(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      },
      floatingActionButton: _CaptureButton(
        compact: compact,
        onPressed: vm.picking ? null : chooseSource,
      ),
    );
  }
}

/// "기록하기". 이 앱에서 그림자가 있는 것은 이 버튼 하나다(DESIGN.md 깊이).
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: [captureShadow],
      ),
      child: compact
          ? SizedBox.square(
              dimension: 60,
              child: FloatingActionButton(
                tooltip: '기록하기',
                onPressed: onPressed,
                child: const Icon(Icons.photo_camera_rounded),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: onPressed,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('기록하기'),
            ),
    );
  }
}

/// 시간대 하나를 담는 카드(`dose-card`). 지금 먹을 시간대는 바이올렛 테두리.
class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.time,
    required this.slots,
    required this.current,
    required this.onTap,
  });

  final int time;
  final List<DoseSlot> slots;
  final bool current;
  final void Function(DoseSlot) onTap;

  @override
  Widget build(BuildContext context) {
    final done = slots.where((s) => s.isDone).length;
    return GroupCard(
      highlighted: current,
      children: [
        _CardHeader(
          title: formatMinuteOfDay(time),
          badge: current ? '지금 먹을 약' : null,
          progress: '$done / ${slots.length}',
        ),
        for (final slot in slots)
          _Row(
            leading: StatusDot(taken: slot.isDone),
            title: slot.medication.name,
            subtitle: '1회 ${slot.dose}정',
            trailing: _SlotStatus(slot: slot),
            onTap: slot.isDone ? null : () => onTap(slot),
          ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.badge, this.progress});

  final String title;
  final String? badge;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: AppTypography.headline.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              badge!,
              style: AppTypography.captionStrong.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
          const Spacer(),
          if (progress != null)
            Text(
              progress!,
              style: AppTypography.caption.copyWith(
                color: AppColors.inkMuted,
                fontFeatures: AppTypography.tabular,
              ),
            ),
        ],
      ),
    );
  }
}

/// 카드 안 약 한 줄(`dose-row`). 높이 52 이상, 줄 전체가 눌린다.
class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyStrong),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing,
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
    final dose = slot.dose;
    final (text, color) = switch (slot) {
      DoseSlot(isDone: true) => ('완료', AppColors.primary),
      DoseSlot(taken: > 0) => ('$dose정 중 ${slot.taken}정', reviewColor),
      _ => ('예정', AppColors.inkMuted),
    };
    return Text(
      text,
      style: AppTypography.callout.copyWith(
        color: color,
        fontWeight: slot.isDone ? FontWeight.w600 : null,
        fontFeatures: AppTypography.tabular,
      ),
    );
  }
}

/// 업데이트 전에 등록해 종류가 없는 약. 눌러서 종류를 고른다 (docs/MVP.md 10장).
class _KindPrompt extends StatelessWidget {
  const _KindPrompt({required this.medications, required this.onTap});

  final List<Medication> medications;
  final void Function(Medication) onTap;

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      highlighted: true,
      children: [
        const _CardHeader(title: '약 종류를 골라 주세요'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xs,
          ),
          child: Text(
            '영양제, 처방약, 필요할 때 먹는 약에 따라 하루 기준이 달라져요.',
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
        ),
        for (final m in medications)
          _Row(
            leading: const Icon(
              Icons.help_outline_rounded,
              size: 22,
              color: AppColors.inkMuted,
            ),
            title: m.name,
            subtitle: '종류 없음',
            trailing: Text(
              '고르기',
              style: AppTypography.callout.copyWith(color: AppColors.primary),
            ),
            onTap: () => onTap(m),
          ),
      ],
    );
  }
}

/// 오늘 기록도 일정도 없을 때(`empty-guide`). 무엇을 하면 되는지와 잘 찍는 법을 함께 보여 준다.
class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide({
    this.header,
    required this.onTrySample,
    required this.onSetSchedule,
  });

  /// 안내 위에 둘 카드. 종류를 고르지 않은 약이 있을 때.
  final Widget? header;
  final VoidCallback onTrySample;
  final VoidCallback onSetSchedule;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: pagePadding(context, top: AppSpacing.lg, bottom: 120),
      children: [
        if (header != null) ...[header!, const SizedBox(height: AppSpacing.xl)],
        Text('오늘 기록이 없습니다', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '알약 사진을 찍거나 올리면 인식한 약이 바로 기록됩니다.',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이렇게 찍어 주세요', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final (icon, text) in const [
                  (Icons.crop_square_rounded, '단색 배경 위에 놓기'),
                  (Icons.photo_camera_rounded, '바로 위에서 수직으로 찍기'),
                  (Icons.scatter_plot_rounded, '알약끼리 떨어지게 놓기'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(text, style: textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  style: tonalButtonStyle,
                  onPressed: onTrySample,
                  child: const Text('샘플 사진으로 해 보기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onSetSchedule,
            child: const Text('복용 시간 정하기'),
          ),
        ),
      ],
    );
  }
}
