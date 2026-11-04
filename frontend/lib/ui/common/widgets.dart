import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// 화면 좌우 여백. 작은 휴대폰은 16, 그 밖에는 20 (DESIGN.md 화면 크기별).
double gutterOf(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppLayout.compact
    ? AppSpacing.md
    : AppSpacing.gutter;

/// 화면을 채우는 목록의 안쪽 여백. 넓은 화면에서는 본문을 [maxWidth] 폭으로 가운데 둔다.
EdgeInsets pagePadding(
  BuildContext context, {
  double top = AppSpacing.xs,
  double bottom = AppSpacing.lg,
  double maxWidth = AppLayout.content,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = max(gutterOf(context), (width - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// 목록 안의 한 덩어리를 본문 폭에 맞춰 가운데 두고 좌우 여백을 준다.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.content,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // 높이는 내용만큼. 하단 바 안에 둘 때 화면을 채우지 않게 한다.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutterOf(context)),
          child: child,
        ),
      ),
    );
  }
}

/// 카드 위 섹션 이름. 작고 흐리게 둬서 카드 안 약 이름이 먼저 읽히게 한다.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.first = false});

  final String text;

  /// 화면 맨 위 섹션이면 위 여백을 줄인다.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxs,
        first ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTypography.captionStrong.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

/// 줄 여러 개를 담는 흰 카드. 줄 사이에 부드러운 구분선을 넣는다.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.children,
    this.highlighted = false,
  });

  final List<Widget> children;

  /// 지금 시간대처럼 강조할 카드. 배경은 그대로 두고 2px 바이올렛 테두리만 더한다.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        side: highlighted
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              const Divider(
                indent: AppSpacing.gutter,
                endIndent: AppSpacing.gutter,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// 화면 아래 고정 영역. 크림 바탕, 위쪽 헤어라인, 버튼 위아래 12·좌우 20.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(spacing: AppSpacing.sm, children: children),
          ),
        ),
      ),
    );
  }
}

/// 수량 조절기. 들어간 면 알약 모양에 −/숫자/+. 높이는 36이지만 누르는 영역은 넓힌다.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.label,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementTooltip,
    required this.incrementTooltip,
  });

  final String label;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String decrementTooltip;
  final String incrementTooltip;

  static final _buttonStyle = IconButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    minimumSize: const Size(44, 44),
    maximumSize: const Size(44, 44),
    iconSize: 20,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    // 바탕은 위아래 4씩 들여 36으로 보이게 하고, 버튼은 44를 꽉 채워 누르기 쉽게 한다.
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          top: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: AppColors.surfaceSunken,
              shape: StadiumBorder(),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: decrementTooltip,
              style: _buttonStyle,
              onPressed: onDecrement,
              icon: const Icon(Icons.remove_rounded),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.bodyStrong.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
            IconButton(
              tooltip: incrementTooltip,
              style: _buttonStyle,
              onPressed: onIncrement,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// 복용 상태 점. 먹었으면 바이올렛 채운 원에 흰 체크, 아니면 흐린 테두리의 빈 원.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: taken ? AppColors.primary : null,
          border: taken
              ? null
              : Border.all(color: AppColors.inkMuted, width: 1.5),
        ),
        child: taken
            ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.onPrimary,
              )
            : null,
      ),
    );
  }
}

/// 알약 모양 검색창. 들어간 면 바탕, 테두리 없음, 포커스 때만 2px 바이올렛.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  static OutlineInputBorder _border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: side,
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: onSubmitted == null ? null : TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: AppColors.surfaceSunken,
        constraints: const BoxConstraints(minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
          child: Icon(Icons.search_rounded, color: AppColors.inkMuted),
        ),
        prefixIconConstraints: const BoxConstraints(minHeight: 48),
        border: _border(BorderSide.none),
        enabledBorder: _border(BorderSide.none),
        focusedBorder: _border(
          const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

/// 바텀 시트 제목.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

/// 바텀 시트 안 섹션 제목("추천", "약 목록").
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xxs,
      ),
      child: Text(
        text,
        style: AppTypography.captionStrong.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}

/// 목록이 비었을 때. 아이콘, 제목, 설명, 그리고 다음에 할 일.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: pagePadding(
          context,
          top: AppSpacing.xl,
          bottom: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 불러오는 중. 설명이 있으면 아래에 흐리게.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
