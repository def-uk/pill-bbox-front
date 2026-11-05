import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../data/services/image_save_service.dart';
import '../../utils/time_format.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'share_card.dart';

/// 공유 카드 미리보기와 저장 (docs/MVP.md 8장). 웹은 내려받기로 저장한다.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.data, this.now});

  final ShareCardData data;
  final DateTime Function()? now;

  /// 저장하는 이미지 폭(픽셀).
  static const imageWidth = 1080.0;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  /// 카드를 PNG로 그린다.
  Future<Uint8List> _render() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: ShareCardScreen.imageWidth / boundary.size.width,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final saver = context.read<ImageSaveService>();
    setState(() => _saving = true);
    String message;
    try {
      final now = (widget.now ?? DateTime.now)();
      final saved = await saver.savePng(
        '알약몬-캐릭터-${dateKey(now)}.png',
        await _render(),
      );
      message = saved ? '이미지로 저장했어요' : '';
    } catch (_) {
      message = '저장하지 못했어요';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (message.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공유 카드')),
      body: ListView(
        padding: pagePadding(context, top: AppSpacing.md, maxWidth: 480),
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
            child: RepaintBoundary(
              key: _cardKey,
              child: ShareCard(data: widget.data),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '내 캐릭터만 들어가요. 약 이름, 병명, 복용 기록은 들어가지 않아요.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('이미지로 저장'),
            ),
          ),
        ],
      ),
    );
  }
}
