import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/medication.dart';
import '../../utils/intake_matcher.dart';
import '../common/kind_picker.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'result_view_model.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResultViewModel>();

    Future<void> save() async {
      final messenger = ScaffoldMessenger.of(context);
      if (await vm.save() && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(['복용 기록을 저장했습니다', ?vm.rewardMessage].join(' · ')),
          ),
        );
        context.pop();
      } else if (vm.errorMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
    }

    Future<PillChoice?> pick(
      String title, {
      List<(PillChoice, String)> suggestions = const [],
    }) => showModalBottomSheet<PillChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChoiceSearchSheet(
        title: title,
        choices: vm.choices,
        suggestions: suggestions,
      ),
    );

    PillChoice choiceOf(Medication m) =>
        PillChoice(medication: m, categoryId: m.categoryId, name: m.name);

    Future<void> identify(UnknownObject object) async {
      final similar = object.suggestion;
      final choice = await pick(
        '물체 ${object.number}은(는) 어떤 약인가요?',
        suggestions: [
          if (similar != null) (choiceOf(similar), '예전에 기록한 약과 색·모양이 비슷해요'),
        ],
      );
      if (choice != null) vm.identify(object, choice);
    }

    Future<void> changeMedication(ResultLine line) async {
      final correction = vm.correctionOf(line);
      final choice = await pick(
        '${line.name}을(를) 어떤 약으로 바꿀까요?',
        suggestions: [
          if (correction != null)
            (choiceOf(correction), '예전에 기록한 약과 색·모양이 비슷해요'),
          for (final c in vm.alternativesOf(line))
            if (c.medication == null || c.medication!.id != correction?.id)
              (c, '모델이 이 약과 헷갈렸어요'),
        ],
      );
      if (choice != null) vm.changeMedication(line, choice);
    }

    Future<void> pickNewKind(ResultLine line) async {
      final kind = await pickKind(
        context,
        title: '${line.name}은(는) 어떤 약인가요?',
        current: line.kind,
      );
      if (kind != null) vm.setNewKind(line, kind);
    }

    Future<void> addMedication() async {
      final choice = await pick('추가할 약');
      if (choice != null) vm.addMedication(choice);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('결과 확인')),
      body: switch (vm.status) {
        ResultStatus.detecting => const LoadingState(message: '알약을 찾는 중'),
        ResultStatus.failed => EmptyState(
          icon: Icons.error_outline_rounded,
          title: vm.errorMessage ?? '',
        ),
        ResultStatus.ready || ResultStatus.saving => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            _PhotoWithBoxes(vm: vm),
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?_CompareSummary.of(vm.lines),
                  if (vm.noPills)
                    _NoPills(
                      hasUnknowns: vm.unknowns.isNotEmpty,
                      modelFailed: vm.modelFailed,
                    ),
                  if (vm.unknowns.isNotEmpty) ...[
                    const SectionLabel('알 수 없는 물체'),
                    GroupCard(
                      children: [
                        for (final object in vm.unknowns)
                          _UnknownRow(
                            object: object,
                            onTap: () => identify(object),
                            onDismiss: () => vm.dismiss(object),
                          ),
                      ],
                    ),
                  ],
                  if (vm.lines.isNotEmpty) ...[
                    const SectionLabel('인식된 약'),
                    GroupCard(
                      children: [
                        for (final line in vm.lines)
                          _ResultRow(
                            line: line,
                            correction: vm.correctionOf(line),
                            onTap: () => changeMedication(line),
                            onPickKind: line.isRegistered
                                ? null
                                : () => pickNewKind(line),
                            onDecrement: line.count > 0
                                ? () => vm.decrement(line)
                                : null,
                            onIncrement: () => vm.increment(line),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      style: tonalButtonStyle,
                      onPressed: addMedication,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('약 추가'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      },
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: vm.status == ResultStatus.saving
                  ? null
                  : () => context.pop(),
              child: const Text('다른 사진'),
            ),
          ),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: vm.canSave ? save : null,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 박스와 줄의 색. 예전 기록에서 더 비슷한 약이 있으면 확인이 필요한 색으로 둔다.
Color _markColor({required bool review}) =>
    review ? AppColors.review : AppColors.primary;

/// 사진 바로 아래, 예정과 비교한 한 줄 요약(`compare-summary`). 이 앱의 핵심 화면 요소다.
/// 다 맞으면 연한 바이올렛, 예정과 다른 약이 있으면 연한 주황.
class _CompareSummary extends StatelessWidget {
  const _CompareSummary({required this.text, required this.review});

  final String text;
  final bool review;

  /// 지금 예정된 약이 하나도 없으면 비교할 것이 없어 null.
  static _CompareSummary? of(List<ResultLine> lines) {
    final scheduled = [
      for (final l in lines)
        if (l.status != MatchStatus.unscheduled) l,
    ];
    if (scheduled.isEmpty) return null;
    return _CompareSummary(
      text: [
        for (final l in scheduled)
          switch (l.status) {
            MatchStatus.ok => '${l.name} ${l.count}정 ✓',
            MatchStatus.missing => '${l.name} ${l.expected}정 중 ${l.count}정 인식',
            MatchStatus.extra =>
              '${l.name} ${l.expected}정보다 ${l.count - l.expected}정 많음',
            MatchStatus.unscheduled => '',
          },
      ].join(', '),
      review: scheduled.any((l) => l.status != MatchStatus.ok),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = review ? AppColors.review : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: review ? AppColors.reviewSoft : AppColors.primarySoft,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                review
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodyStrong.copyWith(
                    color: review ? AppColors.review : AppColors.ink,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 탐지된 약 한 줄(`result-row`). 줄을 누르면 약을 바꾸는 시트가 열린다.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.line,
    required this.correction,
    required this.onTap,
    required this.onDecrement,
    required this.onIncrement,
    this.onPickKind,
  });

  final ResultLine line;
  final Medication? correction;
  final VoidCallback onTap;

  /// 처음 기록하는 약의 종류 고르기. 등록한 약이면 null.
  final VoidCallback? onPickKind;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              // 사진 위 박스와 같은 색의 점.
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _markColor(review: correction != null),
                ),
                child: const SizedBox.square(dimension: 10),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.name, style: AppTypography.bodyStrong),
                    _LineStatus(line: line, correction: correction),
                    if (onPickKind != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onPickKind,
                        child: Text(
                          line.kind == null
                              ? '종류 고르기'
                              : '종류 · ${line.kind!.label}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              CountStepper(
                label: '${line.count}정',
                decrementTooltip: '${line.name} 하나 빼기',
                incrementTooltip: '${line.name} 하나 더하기',
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 모델이 알약으로 보지 않은 물체 한 줄. 사진 위 점선 박스와 같은 번호.
class _UnknownRow extends StatelessWidget {
  const _UnknownRow({
    required this.object,
    required this.onTap,
    required this.onDismiss,
  });

  final UnknownObject object;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cream,
                  border: Border.all(color: AppColors.ink),
                ),
                child: Text(
                  '${object.number}',
                  style: AppTypography.captionStrong.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '물체 ${object.number}',
                      style: AppTypography.bodyStrong,
                    ),
                    Text(
                      object.suggestion == null
                          ? '눌러서 어떤 약인지 고르기'
                          : '${object.suggestion!.name}과(와) 비슷해요 · 눌러서 고르기',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: '물체 ${object.number}은(는) 약이 아님',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 예정과 비교한 결과. 예: "예정대로", "예정 2정 중 1정". 예전 기록에서 더 비슷한 약이 있으면 함께 알린다.
class _LineStatus extends StatelessWidget {
  const _LineStatus({required this.line, this.correction});

  final ResultLine line;
  final Medication? correction;

  @override
  Widget build(BuildContext context) {
    const muted = AppColors.inkMuted;
    final (text, color) = switch (line) {
      ResultLine(isRegistered: false) => ('처음 기록하는 약 · 저장하면 약 목록에 추가', muted),
      ResultLine(status: MatchStatus.ok) => ('✓ 예정대로', AppColors.primary),
      ResultLine(status: MatchStatus.missing) => (
        '예정 ${line.expected}정 중 ${line.count}정',
        reviewColor,
      ),
      ResultLine(status: MatchStatus.extra) => (
        '예정 ${line.expected}정보다 많음',
        reviewColor,
      ),
      ResultLine(status: MatchStatus.unscheduled) => ('지금 예정에 없는 약', muted),
    };
    final status = Text(
      text,
      style: AppTypography.caption.copyWith(color: color),
    );
    if (correction == null) return status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        Text(
          '${correction!.name}과(와) 더 비슷해요 · 눌러서 바꾸기',
          style: AppTypography.caption.copyWith(color: reviewColor),
        ),
      ],
    );
  }
}

/// 모델이 알약을 하나도 찾지 못했거나, 모델을 쓰지 못했을 때.
class _NoPills extends StatelessWidget {
  const _NoPills({required this.hasUnknowns, required this.modelFailed});

  final bool hasUnknowns;
  final bool modelFailed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text(
                modelFailed ? '알약 인식 모델을 쓰지 못했습니다' : '알약이 없습니다',
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                switch ((modelFailed, hasUnknowns)) {
                  (true, true) => '색으로 찾은 물체를 눌러 어떤 약인지 알려 주세요.',
                  (true, false) => '약을 직접 추가하거나 잠시 뒤 다시 해 주세요.',
                  (false, true) =>
                    '알약으로 보이지 않는 물체가 있습니다. 약이 맞다면 눌러서 무엇인지 알려 주세요.',
                  (false, false) =>
                    '사진에서 알약을 찾지 못했습니다. 다른 사진을 쓰거나 약을 직접 추가해 주세요.',
                },
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고를 약을 이름으로 찾는 시트. 추천한 약, 등록한 약 순서로 나오고, 없으면 이름을 직접 넣는다.
class _ChoiceSearchSheet extends StatefulWidget {
  const _ChoiceSearchSheet({
    required this.title,
    required this.choices,
    this.suggestions = const [],
  });

  final String title;
  final List<PillChoice> choices;

  /// 맨 위에 둘 약과 추천하는 까닭: 색·모양이 비슷한 약이나 모델이 헷갈린 약.
  final List<(PillChoice, String)> suggestions;

  @override
  State<_ChoiceSearchSheet> createState() => _ChoiceSearchSheetState();
}

class _ChoiceSearchSheetState extends State<_ChoiceSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final suggestions = _query.isEmpty ? widget.suggestions : const [];
    bool suggested(PillChoice c) => suggestions.any(
      (s) => s.$1.medication != null
          ? s.$1.medication!.id == c.medication?.id
          : c.medication == null && s.$1.categoryId == c.categoryId,
    );
    final matches = [
      for (final c in widget.choices)
        if (c.name.toLowerCase().contains(_query.toLowerCase()) &&
            !suggested(c))
          c,
    ];
    final exact = widget.choices.any((c) => c.name == _query);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(widget.title),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: SearchField(
                hintText: '약 이름 검색 · 없으면 이름 입력',
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                children: [
                  if (suggestions.isNotEmpty) const SheetSectionLabel('추천'),
                  for (final (c, note) in suggestions)
                    ListTile(
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(c.name),
                      subtitle: Text(note),
                      onTap: () => Navigator.pop(context, c),
                    ),
                  if (suggestions.isNotEmpty && matches.isNotEmpty)
                    const SheetSectionLabel('약 목록'),
                  for (final c in matches)
                    ListTile(
                      title: Text(c.name),
                      subtitle: c.medication == null
                          ? null
                          : Text('등록한 약 · 1회 ${c.medication!.dosePerTake}정'),
                      onTap: () => Navigator.pop(context, c),
                    ),
                  if (_query.isNotEmpty && !exact)
                    ListTile(
                      leading: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text("'$_query' 새 약으로 등록"),
                      subtitle: const Text('목록에 없는 약. 다음부터는 색·모양으로 추천해요'),
                      onTap: () =>
                          Navigator.pop(context, PillChoice.custom(_query)),
                    ),
                  if (matches.isEmpty && _query.isEmpty && suggestions.isEmpty)
                    const ListTile(title: Text('찾는 약이 없습니다')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 위에 탐지 박스를 그린다. 박스 좌표를 맞추려고 사진의 픽셀 크기를 직접 읽는다.
class _PhotoWithBoxes extends StatefulWidget {
  const _PhotoWithBoxes({required this.vm});

  final ResultViewModel vm;

  @override
  State<_PhotoWithBoxes> createState() => _PhotoWithBoxesState();
}

class _PhotoWithBoxesState extends State<_PhotoWithBoxes> {
  late final MemoryImage _image = MemoryImage(widget.vm.photo);
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) {
      setState(
        () => _size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
      );
    }
  });
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = _image.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) {
      return const ContentWidth(
        maxWidth: AppLayout.photo,
        child: AspectRatio(aspectRatio: 4 / 3),
      );
    }
    final vm = widget.vm;
    // 확인이 필요한 줄(더 비슷한 약이 있는 줄)의 약은 박스도 확인 필요 색으로 그린다.
    final reviewCategories = {
      for (final l in vm.lines)
        if (l.categoryId != null && vm.correctionOf(l) != null) l.categoryId!,
    };
    // 사진 액자: 검은 바탕, 둥글기 lg (DESIGN.md photo-frame). 원본 비율 그대로,
    // 최대 폭 720, 화면 높이의 60%를 넘지 않게 줄인다.
    final aspect = size.width / size.height;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return ContentWidth(
      maxWidth: AppLayout.photo,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SizedBox(
              width: min(constraints.maxWidth, maxHeight * aspect),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.lg),
                ),
                child: ColoredBox(
                  color: AppColors.surfacePhoto,
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: _image,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                        CustomPaint(
                          painter: _BoxPainter(
                            photoSize: size,
                            marks: [
                              for (final d in vm.detections)
                                (
                                  d.box,
                                  '${d.name} ${(d.confidence * 100).round()}%',
                                  reviewCategories.contains(d.categoryId)
                                      ? _MarkKind.review
                                      : _MarkKind.pill,
                                ),
                              for (final o in vm.unknowns)
                                (o.box, '${o.number}', _MarkKind.unknown),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 박스 종류. 색과 함께 선 모양(실선/점선)과 이름표 모양(이름/번호)으로도 구분한다.
enum _MarkKind { pill, review, unknown }

/// 박스 하나: 원본 이미지 픽셀 좌표, 이름표, 종류.
typedef _Mark = (Rect box, String label, _MarkKind kind);

class _BoxPainter extends CustomPainter {
  // 웹은 한글 글꼴을 필요할 때 받는다. 받은 뒤 다시 그리지 않으면 약 이름 일부가 □로 남는다.
  _BoxPainter({required this.marks, required this.photoSize})
    : super(repaint: PaintingBinding.instance.systemFonts);

  final List<_Mark> marks;
  final Size photoSize;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / photoSize.width;
    final scaleY = size.height / photoSize.height;
    for (final (box, text, kind) in marks) {
      final unknown = kind == _MarkKind.unknown;
      final color = switch (kind) {
        _MarkKind.pill => AppColors.primary,
        _MarkKind.review => AppColors.review,
        _MarkKind.unknown => AppColors.cream,
      };
      final rect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );
      final shape = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(AppRadius.xs),
      );
      // 어떤 사진 위에서도 보이도록 바깥에 대비되는 선을 한 겹 더 두른다.
      canvas.drawRRect(
        shape.inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = unknown ? AppColors.ink : AppColors.surface,
      );
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;
      if (unknown) {
        // 알 수 없는 물체는 색이 아니라 점선으로도 구분한다.
        _drawDashed(canvas, Path()..addRRect(shape), stroke);
      } else {
        canvas.drawRRect(shape, stroke);
      }
      _drawLabel(canvas, size, rect, text, color, unknown);
    }
  }

  /// 박스 위 왼쪽 이름표. 약은 알약 모양 이름표, 알 수 없는 물체는 번호 원.
  void _drawLabel(
    Canvas canvas,
    Size size,
    Rect rect,
    String text,
    Color color,
    bool unknown,
  ) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.boxLabel.copyWith(
          color: unknown ? AppColors.ink : AppColors.onPrimary,
          fontFeatures: AppTypography.tabular,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 16);
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final height = label.height + padding.vertical;
    // 번호 원은 가로세로가 같다.
    final width = unknown
        ? max(height, label.width + padding.vertical)
        : label.width + padding.horizontal;
    final above = rect.top - height - 4;
    final left = rect.left.clamp(
      0.0,
      (size.width - width).clamp(0.0, size.width),
    );
    final tag = Rect.fromLTWH(
      left,
      above < 0 ? rect.top + 4 : above,
      width,
      height,
    );
    final pill = RRect.fromRectAndRadius(tag, Radius.circular(height / 2));
    canvas.drawRRect(pill, Paint()..color = color);
    if (unknown) {
      canvas.drawRRect(
        pill,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.ink,
      );
    }
    label.paint(canvas, tag.center - Offset(label.width / 2, label.height / 2));
  }

  static void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      !listEquals(old.marks, marks) || old.photoSize != photoSize;
}
