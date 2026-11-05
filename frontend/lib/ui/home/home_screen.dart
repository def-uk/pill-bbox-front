import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import '../../data/models/medication.dart';
import '../../utils/intake_matcher.dart';
import '../../utils/reward_calculator.dart';
import '../../utils/time_format.dart';
import '../common/creature_art.dart';
import '../common/kind_picker.dart';
import '../common/medication_picker.dart';
import '../common/stage_widgets.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import '../shell/app_shell.dart';
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
        ? [
            _RecentRecords(
              records: vm.recent,
              nameOf: vm.nameOf,
              onSeeAll: () => context.go('/history'),
              onTap: (r) => context.push('/history/${dateKey(r.takenAt)}'),
            ),
          ]
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
                    _RecordRow(
                      record: record,
                      name: vm.nameOf(record.medicationId),
                      when: formatTime(record.takenAt),
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
              onTapCharacter: () => showModalBottomSheet<void>(
                context: context,
                // 탭 화면에서 열어도 아래 바와 기록하기 버튼 위에 뜨게 한다.
                useRootNavigator: true,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _CharacterSheet(vm: vm),
              ),
            ),
            if (vm.reminder case final reminder?) ...[
              const SizedBox(height: AppSpacing.md),
              ContentWidth(
                child: _ReminderCard(
                  reminder: reminder,
                  onTap: () => showCaptureSheet(context),
                ),
              ),
            ],
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

/// 기록 한 줄: 사진/직접 아이콘, 약 이름, 시각, 개수.
class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.name,
    required this.when,
    this.onTap,
  });

  final IntakeRecord record;
  final String name;
  final String when;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Row(
      leading: Icon(
        record.source == IntakeSource.camera
            ? Icons.photo_camera_rounded
            : Icons.edit_rounded,
        size: 22,
        color: AppColors.inkMuted,
      ),
      title: name,
      subtitle: when,
      trailing: Text(
        '${record.count}정',
        style: AppTypography.bodyStrong.copyWith(
          fontFeatures: AppTypography.tabular,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// 오늘 일정도 기록도 없을 때. 최근 기록만 보여 준다. 일정 정하기는 약 관리 탭, 찍는 법은 기록하기 시트에 있다.
class _RecentRecords extends StatelessWidget {
  const _RecentRecords({
    required this.records,
    required this.nameOf,
    required this.onSeeAll,
    required this.onTap,
  });

  /// 최근 것부터.
  final List<IntakeRecord> records;
  final String Function(int medicationId) nameOf;
  final VoidCallback onSeeAll;
  final void Function(IntakeRecord) onTap;

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
          '아래 기록하기로 알약 사진을 찍어 보세요',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
        ),
        if (records.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          GroupCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.xxs,
                  0,
                ),
                child: Row(
                  children: [
                    Text('최근 기록', style: AppTypography.headline),
                    const Spacer(),
                    TextButton(onPressed: onSeeAll, child: const Text('전체 보기')),
                  ],
                ),
              ),
              for (final record in records)
                _RecordRow(
                  record: record,
                  name: nameOf(record.medicationId),
                  when: formatMonthDayTime(record.takenAt),
                  onTap: () => onTap(record),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 복용 시간이 되면 홈 위에 뜨는 알림 카드 (상황 A · 5쪽). 누르면 바로 찍는다.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.onTap});

  final DoseReminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.cream,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알약몬 · ${formatMinuteOfDay(reminder.time)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkDisabled,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    Text(
                      reminder.title,
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.cream,
                      ),
                    ),
                    Text(
                      reminder.detail,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '바로 찍기',
                style: AppTypography.captionStrong.copyWith(
                  color: AppColors.primaryOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 캐릭터를 누르면 뜨는 성장 정보 (상황 B · 13쪽): 단계, 경험치, 연속 기록, 오늘 영양제 보상.
class _CharacterSheet extends StatelessWidget {
  const _CharacterSheet({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final growth = vm.growth;
    final stage = growth.stage;
    final streak = vm.streak;
    final toTicket = ticketStreakDays - streak % ticketStreakDays;
    final (icon, today) = switch (vm) {
      _ when !vm.hasSupplementsToday => (
        Icons.event_note_rounded,
        '영양제 일정을 정하면 다 지킨 날마다 경험치 +$supplementDayExp',
      ),
      _ when vm.supplementsDoneToday => (
        Icons.verified_rounded,
        '오늘 권장량 채움 · 더 먹어도 경험치는 그대로',
      ),
      _ => (
        Icons.radio_button_unchecked_rounded,
        '오늘 영양제 일정을 다 지키면 경험치 +$supplementDayExp',
      ),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 캐릭터', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: CharacterWithPet(
                stageExp: growth.exp,
                skinId: vm.equipment.skin?.id,
                accessoryId: vm.equipment.accessory?.id,
                pet: vm.pet,
                size: 140,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '성장 ${stage.index + 1}단계 · ${stage.label}',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('경험치', style: textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${(growth.progress * 100).round()}%',
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.primary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            GrowthBar(growth: growth),
            const SizedBox(height: AppSpacing.md),
            Row(
              spacing: AppSpacing.xs,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_fire_department_rounded,
                    value: '$streak일',
                    label: '연속 기록',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.confirmation_number_rounded,
                    value: '$toTicket일',
                    label: '다음 뽑기권까지',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    today,
                    style: AppTypography.callout.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTypography.bodyStrong.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
