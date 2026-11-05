import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/photo_picker_service.dart';
import '../common/theme.dart';
import '../common/widgets.dart';
import 'capture_view_model.dart';

/// 아래 바의 탭. 가운데 칸은 "기록하기"가 차지한다.
const _tabs = [
  (path: '/', icon: Icons.home_rounded, label: '홈'),
  (path: '/history', icon: Icons.calendar_month_rounded, label: '기록'),
  (path: '/collection', icon: Icons.auto_awesome_rounded, label: '컬렉션'),
  (path: '/medications', icon: Icons.medication_rounded, label: '약 관리'),
];

/// 홈·기록·컬렉션·약 관리를 담는 틀. 아래 바 가운데에 "기록하기"가 떠 있다.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// 지금 경로. 어느 탭이 켜져 있는지 정한다.
  final String location;
  final Widget child;

  int get _current {
    for (final (i, tab) in _tabs.indexed.skip(1)) {
      if (location.startsWith(tab.path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final capture = context.watch<CaptureViewModel>();
    final onCapture = capture.picking ? null : () => showCaptureSheet(context);
    final current = _current;

    Widget tab(int i) {
      final t = _tabs[i];
      return _TabItem(
        icon: t.icon,
        label: t.label,
        selected: i == current,
        onTap: () => context.go(t.path),
      );
    }

    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CaptureButton(onPressed: onCapture),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        elevation: 0,
        height: 68,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          children: [
            Expanded(child: tab(0)),
            Expanded(child: tab(1)),
            // 떠 있는 버튼 아래 이름. 눌러도 같은 시트가 열린다.
            Expanded(
              child: Semantics(
                excludeSemantics: true,
                child: InkWell(
                  onTap: onCapture,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '기록하기',
                        style: AppTypography.captionStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: tab(2)),
            Expanded(child: tab(3)),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (selected
                          ? AppTypography.captionStrong
                          : AppTypography.caption)
                      .copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// "기록하기". 이 앱에서 그림자가 있는 것은 이 버튼 하나다(DESIGN.md 깊이).
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: CircleBorder(),
        shadows: [captureShadow],
      ),
      child: SizedBox.square(
        dimension: 64,
        child: FloatingActionButton(
          // 탭 화면에도 떠 있는 버튼이 있어 화면 전환 때 겹치지 않게 한다.
          heroTag: null,
          tooltip: '기록하기',
          shape: const CircleBorder(),
          onPressed: onPressed,
          child: const Icon(Icons.photo_camera_rounded, size: 30),
        ),
      ),
    );
  }
}

/// 사진 찍기·올리기·샘플 사진 중에서 고르는 시트.
///
/// 웹은 사용자가 누른 그 순간에 열어야 브라우저가 카메라·파일 창을 막지 않는다.
/// 그래서 시트를 닫는 것과 같은 탭 처리 안에서 바로 연다.
void showCaptureSheet(BuildContext context) {
  final capture = context.read<CaptureViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  void showResult(Uint8List? photo) {
    if (photo != null && context.mounted) {
      context.push('/result', extra: photo);
    }
  }

  Future<void> pick(PhotoSource source) async {
    try {
      showResult(await capture.pickPhoto(source));
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

  Future<void> trySample() async {
    final photo = await capture.loadSamplePhoto();
    if (photo == null) {
      messenger.showSnackBar(const SnackBar(content: Text('샘플 사진이 없습니다')));
    }
    showResult(photo);
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
          const SheetTitle('기록하기'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xs,
                children: [
                  for (final (icon, label, onTap) in [
                    (
                      Icons.photo_camera_rounded,
                      '사진 찍기',
                      () => pick(PhotoSource.camera),
                    ),
                    (
                      Icons.photo_library_rounded,
                      '사진 올리기',
                      () => pick(PhotoSource.gallery),
                    ),
                    (Icons.science_rounded, '샘플 사진', trySample),
                  ])
                    Expanded(
                      // 시트 안의 큰 선택지라 담는 모양(둥근 사각형)으로 둔다.
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxs,
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
                          onTap();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 32),
                            const SizedBox(height: AppSpacing.xs),
                            Text(label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Text(
              '알약 사진이 없으면 샘플 사진으로 기록을 해 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}
