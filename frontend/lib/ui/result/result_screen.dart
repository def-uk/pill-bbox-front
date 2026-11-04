import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/medication.dart';
import '../../utils/intake_matcher.dart';
import '../common/theme.dart';
import 'result_view_model.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResultViewModel>();

    Future<void> save() async {
      final messenger = ScaffoldMessenger.of(context);
      if (await vm.save() && context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('복용 기록을 저장했습니다')));
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

    Future<void> addMedication() async {
      final choice = await pick('추가할 약');
      if (choice != null) vm.addMedication(choice);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('결과 확인')),
      body: switch (vm.status) {
        ResultStatus.detecting => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('알약을 찾는 중'),
            ],
          ),
        ),
        ResultStatus.failed => Center(child: Text(vm.errorMessage ?? '')),
        ResultStatus.ready || ResultStatus.saving => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _PhotoWithBoxes(vm: vm),
            if (vm.noPills)
              _NoPills(
                hasUnknowns: vm.unknowns.isNotEmpty,
                modelFailed: vm.modelFailed,
              ),
            if (vm.unknowns.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '알 수 없는 물체',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final object in vm.unknowns)
                ListTile(
                  leading: CircleAvatar(child: Text('${object.number}')),
                  title: Text('물체 ${object.number}'),
                  subtitle: Text(
                    object.suggestion == null
                        ? '눌러서 어떤 약인지 고르기'
                        : '${object.suggestion!.name}과(와) 비슷해요 · 눌러서 고르기',
                  ),
                  onTap: () => identify(object),
                  trailing: IconButton(
                    tooltip: '물체 ${object.number}은(는) 약이 아님',
                    onPressed: () => vm.dismiss(object),
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
            if (vm.lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '인식된 약',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            for (final line in vm.lines)
              ListTile(
                title: Text(line.name),
                subtitle: _LineStatus(
                  line: line,
                  correction: vm.correctionOf(line),
                ),
                onTap: () => changeMedication(line),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '${line.name} 하나 빼기',
                      onPressed: line.count > 0
                          ? () => vm.decrement(line)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${line.count}정'),
                    IconButton(
                      tooltip: '${line.name} 하나 더하기',
                      onPressed: () => vm.increment(line),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: addMedication,
                  icon: const Icon(Icons.add),
                  label: const Text('약 추가'),
                ),
              ),
            ),
          ],
        ),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: vm.status == ResultStatus.saving
                      ? null
                      : () => context.pop(),
                  child: const Text('다른 사진'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: vm.canSave ? save : null,
                  child: const Text('저장'),
                ),
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
    final outline = Theme.of(context).colorScheme.outline;
    final (text, color) = switch (line) {
      ResultLine(isRegistered: false) => ('처음 기록하는 약 · 저장하면 약 목록에 추가', outline),
      ResultLine(status: MatchStatus.ok) => (
        '✓ 예정대로',
        Theme.of(context).colorScheme.primary,
      ),
      ResultLine(status: MatchStatus.missing) => (
        '예정 ${line.expected}정 중 ${line.count}정',
        reviewColor,
      ),
      ResultLine(status: MatchStatus.extra) => (
        '예정 ${line.expected}정보다 많음',
        reviewColor,
      ),
      ResultLine(status: MatchStatus.unscheduled) => ('지금 예정에 없는 약', outline),
    };
    final status = Text(text, style: TextStyle(color: color));
    if (correction == null) return status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        Text(
          '${correction!.name}과(와) 더 비슷해요 · 눌러서 바꾸기',
          style: TextStyle(color: reviewColor),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          Text(
            modelFailed ? '알약 인식 모델을 쓰지 못했습니다' : '알약이 없습니다',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            switch ((modelFailed, hasUnknowns)) {
              (true, true) => '색으로 찾은 물체를 눌러 어떤 약인지 알려 주세요.',
              (true, false) => '약을 직접 추가하거나 잠시 뒤 다시 해 주세요.',
              (false, true) => '알약으로 보이지 않는 물체가 있습니다. 약이 맞다면 눌러서 무엇인지 알려 주세요.',
              (false, false) => '사진에서 알약을 찾지 못했습니다. 다른 사진을 쓰거나 약을 직접 추가해 주세요.',
            },
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ],
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
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '약 이름 검색 · 없으면 이름 입력',
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final (c, note) in suggestions)
                    ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: Text(c.name),
                      subtitle: Text(note),
                      onTap: () => Navigator.pop(context, c),
                    ),
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
                      leading: const Icon(Icons.edit),
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
    if (size == null) return const AspectRatio(aspectRatio: 4 / 3);
    // 사진 액자: 검은 바탕, 둥글기 lg (DESIGN.md photo-frame).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: ColoredBox(
          color: AppColors.surfacePhoto,
          child: AspectRatio(
            aspectRatio: size.width / size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: _image, fit: BoxFit.fill, gaplessPlayback: true),
                CustomPaint(
                  painter: _BoxPainter(
                    photoSize: size,
                    marks: [
                      for (final d in widget.vm.detections)
                        (
                          d.box,
                          '${d.name} ${(d.confidence * 100).round()}%',
                          false,
                        ),
                      for (final o in widget.vm.unknowns)
                        (o.box, '물체 ${o.number}', true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 박스 하나: 원본 이미지 픽셀 좌표, 이름표, 알 수 없는 물체인지.
typedef _Mark = (Rect box, String label, bool unknown);

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
    for (final (box, text, unknown) in marks) {
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
        ..color = unknown ? AppColors.cream : AppColors.primary;
      if (unknown) {
        // 알 수 없는 물체는 색이 아니라 점선으로도 구분한다.
        _drawDashed(canvas, Path()..addRRect(shape), stroke);
      } else {
        canvas.drawRRect(shape, stroke);
      }
      _drawLabel(canvas, size, rect, text, unknown);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Rect rect,
    String text,
    bool unknown,
  ) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: unknown ? AppColors.ink : AppColors.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 16);
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final width = label.width + padding.horizontal;
    final height = label.height + padding.vertical;
    final above = rect.top - height - 4;
    final left = rect.left.clamp(
      0.0,
      (size.width - width).clamp(0.0, size.width),
    );
    final pill = Rect.fromLTWH(
      left,
      above < 0 ? rect.top + 4 : above,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, Radius.circular(height / 2)),
      Paint()..color = unknown ? AppColors.cream : AppColors.primary,
    );
    label.paint(canvas, pill.topLeft + Offset(padding.left, padding.top));
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
