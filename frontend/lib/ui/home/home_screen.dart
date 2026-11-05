import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../data/models/medication.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/time_format.dart';
import '../common/creature_art.dart';
import '../common/kind_picker.dart';
import '../common/medication_picker.dart';
import '../common/stage_widgets.dart';
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

    // 파일 창은 메뉴를 누른 그 처리 안에서 연다(웹은 누른 순간에 열어야 막히지 않는다).
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

    if (vm.loading) return const Scaffold(body: LoadingState());

    final hud = _Hud(
      date: formatDate(vm.today),
      tickets: vm.tickets,
      onDraw: () => context.push('/draw'),
      menu: [
        PopupMenuItem(onTap: exportExcel, child: const Text('엑셀로 내보내기')),
        PopupMenuItem(onTap: importExcel, child: const Text('엑셀에서 가져오기')),
        PopupMenuItem(
          onTap: () => context.push('/metrics'),
          child: const Text('테스트 지표'),
        ),
        PopupMenuItem(
          onTap: () => context.push('/about'),
          child: const Text('앱 안내'),
        ),
      ],
    );

    final List<Widget> today = vm.isEmpty
        ? [_EmptyGuide(onSetSchedule: () => context.go('/medications'))]
        : [
            const SectionLabel('오늘의 퀘스트'),
            for (final (i, (time, slots)) in vm.slotsByTime.indexed) ...[
              // 시간대 카드 사이는 섹션처럼 비워 덩어리로 읽히게 한다.
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _DoseCard(
                time: time,
                slots: slots,
                current: time == vm.currentTime,
                missed: vm.isMissed(time, slots),
                onTap: markTaken,
              ),
            ],
            if (vm.summary.unscheduled.isNotEmpty) ...[
              if (vm.summary.slots.isNotEmpty)
                const SizedBox(height: AppSpacing.md),
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
          ];

    return Scaffold(
      // 카드가 몇 장 안 되어 한 번에 그린다.
      body: SingleChildScrollView(
        // 아래 바에 떠 있는 기록하기 버튼에 마지막 카드가 가리지 않게 비워 둔다.
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StageCard(
              hud: hud,
              growth: vm.growth,
              skinId: vm.equipment.skin?.id,
              accessoryId: vm.equipment.accessory?.id,
              pet: vm.pet,
              monsters: vm.activeMonsters,
              looks: vm.monsterLooks,
              today: vm.today,
              onTapMonster: (m) =>
                  context.push('/monsters/${m.prescription.id}'),
            ),
            if (vm.untyped.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ContentWidth(
                child: _KindPrompt(medications: vm.untyped, onTap: chooseKind),
              ),
            ],
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: today,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 무대 위쪽 줄: 날짜, 뽑기권, 더 보기 메뉴. 하늘 위에 흰 알약 모양으로 얹는다.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.date,
    required this.tickets,
    required this.onDraw,
    required this.menu,
  });

  final String date;
  final int tickets;
  final VoidCallback onDraw;
  final List<PopupMenuEntry<void>> menu;

  @override
  Widget build(BuildContext context) {
    const pill = ShapeDecoration(
      color: AppColors.surface,
      shape: StadiumBorder(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: pill,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              textStyle: AppTypography.bodyStrong.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            onPressed: onDraw,
            icon: const Icon(
              Icons.confirmation_number_rounded,
              color: CreatureColors.crown,
            ),
            label: Text('뽑기 · $tickets장'),
          ),
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<void>(
            tooltip: '더 보기',
            style: IconButton.styleFrom(backgroundColor: AppColors.surface),
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (_) => menu,
          ),
        ],
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
    this.missed = false,
  });

  final int time;
  final List<DoseSlot> slots;
  final bool current;

  /// 회차 시간이 한참 지났는데 다 먹지 않았다.
  final bool missed;
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
        if (missed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '놓친 약은 의사·약사의 안내를 따르세요',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
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
  const _EmptyGuide({required this.onSetSchedule});

  final VoidCallback onSetSchedule;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text('오늘 기록이 없습니다', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '아래 기록하기를 눌러 알약 사진을 찍거나 올리면 인식한 약이 바로 기록됩니다. '
          '사진이 없으면 샘플 사진으로 해 볼 수 있어요.',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            style: tonalButtonStyle,
            onPressed: onSetSchedule,
            child: const Text('복용 시간 정하기'),
          ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
