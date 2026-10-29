import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/detection.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '인식된 약',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (vm.pills.isEmpty)
              const ListTile(title: Text('알약을 찾지 못했습니다. 다시 찍어 주세요.')),
            for (final (i, pill) in vm.pills.indexed)
              ListTile(
                title: Text(pill.name),
                subtitle: pill.needsReview
                    ? const Text('확인 필요', style: TextStyle(color: reviewColor))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '${pill.name} 하나 빼기',
                      onPressed: pill.count > 0 ? () => vm.decrement(i) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${pill.count}정'),
                    IconButton(
                      tooltip: '${pill.name} 하나 더하기',
                      onPressed: () => vm.increment(i),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
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
                      : () => context.pushReplacement('/capture'),
                  child: const Text('다시 찍기'),
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
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: _image, fit: BoxFit.fill, gaplessPlayback: true),
          CustomPaint(
            painter: _BoxPainter(
              detections: widget.vm.detections,
              photoSize: size,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({
    required this.detections,
    required this.photoSize,
    required this.color,
  });

  final List<Detection> detections;
  final Size photoSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / photoSize.width;
    final scaleY = size.height / photoSize.height;
    for (final d in detections) {
      final boxColor = d.confidence < reviewConfidence ? reviewColor : color;
      final rect = Rect.fromLTRB(
        d.box.left * scaleX,
        d.box.top * scaleY,
        d.box.right * scaleX,
        d.box.bottom * scaleY,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = boxColor,
      );
      final label = TextPainter(
        text: TextSpan(
          text: ' ${d.name} ${(d.confidence * 100).round()}% ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            backgroundColor: boxColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final top = rect.top - label.height;
      label.paint(canvas, Offset(rect.left, top < 0 ? rect.top : top));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.detections != detections ||
      old.photoSize != photoSize ||
      old.color != color;
}
