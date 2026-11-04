import 'package:flutter/material.dart';

/// 디자인 토큰. 값과 쓰임은 `DESIGN.md`의 colors를 따른다.
abstract final class AppColors {
  // 브랜드 (로고에서 추출)
  static const primary = Color(0xFF452AF8);
  static const primaryPressed = Color(0xFF3418D6);
  static const primaryOnDark = Color(0xFF8E7BFF);
  static const primarySoft = Color(0xFFECE8FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFEF9EB);

  // 텍스트
  static const ink = Color(0xFF1B1830);
  static const inkMuted = Color(0xFF6B6780);
  static const inkDisabled = Color(0xFFA9A5B8);

  // 면
  static const canvas = cream;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF6F0DF);
  static const surfacePhoto = Color(0xFF000000);
  static const scrim = ink;

  // 선
  static const hairline = Color(0xFFE9E3D2);
  static const dividerSoft = Color(0xFFF1EBDB);

  // 상태
  static const review = Color(0xFFC2410C);
  static const reviewSoft = Color(0xFFFEF1E6);
  static const error = Color(0xFFC9302C);
}

/// 둥글기. 누르는 것은 [pill], 담는 것은 [lg].
abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

/// 확인이 필요한 탐지 결과에 쓰는 색.
const reviewColor = AppColors.review;

/// "기록하기" 버튼에만 쓰는 브랜드 그림자. 다른 곳에는 그림자를 쓰지 않는다.
const captureShadow = BoxShadow(
  color: Color(0x47452AF8), // primary 28%
  offset: Offset(0, 8),
  blurRadius: 24,
);

const _colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.primarySoft,
  onPrimaryContainer: AppColors.primary,
  secondary: AppColors.primary,
  onSecondary: AppColors.onPrimary,
  secondaryContainer: AppColors.primarySoft,
  onSecondaryContainer: AppColors.primary,
  tertiary: AppColors.review,
  onTertiary: AppColors.onPrimary,
  tertiaryContainer: AppColors.reviewSoft,
  onTertiaryContainer: AppColors.review,
  error: AppColors.error,
  onError: AppColors.onPrimary,
  surface: AppColors.canvas,
  onSurface: AppColors.ink,
  onSurfaceVariant: AppColors.inkMuted,
  surfaceContainerLowest: AppColors.surface,
  surfaceContainerLow: AppColors.surface,
  surfaceContainer: AppColors.surface,
  surfaceContainerHigh: AppColors.surface,
  surfaceContainerHighest: AppColors.surfaceSunken,
  outline: AppColors.inkMuted,
  outlineVariant: AppColors.hairline,
  scrim: AppColors.scrim,
  inverseSurface: AppColors.ink,
  onInverseSurface: AppColors.cream,
  inversePrimary: AppColors.primaryOnDark,
  surfaceTint: Colors.transparent,
  shadow: Colors.transparent,
);

TextStyle _style(
  double size,
  FontWeight weight,
  double height,
  double spacing,
) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: spacing,
  color: AppColors.ink,
);

// DESIGN.md typography. 본문은 17, 굵기는 400 / 600 / 700만 쓴다.
final _largeTitle = _style(32, FontWeight.w700, 1.2, -0.8);
final _title = _style(26, FontWeight.w700, 1.25, -0.6);
final _headline = _style(21, FontWeight.w600, 1.3, -0.4);
final _bodyStrong = _style(17, FontWeight.w600, 1.4, -0.3);
final _body = _style(17, FontWeight.w400, 1.5, -0.3);
final _callout = _style(15, FontWeight.w400, 1.45, -0.2);
final _caption = _style(13, FontWeight.w400, 1.4, -0.1);
final _captionStrong = _style(13, FontWeight.w600, 1.3, -0.1);
final _button = _style(17, FontWeight.w600, 1.0, -0.3);

final _textTheme = TextTheme(
  displaySmall: _largeTitle,
  headlineLarge: _largeTitle,
  headlineMedium: _title,
  headlineSmall: _headline,
  titleLarge: _headline,
  titleMedium: _bodyStrong,
  titleSmall: _captionStrong,
  bodyLarge: _body,
  bodyMedium: _callout,
  bodySmall: _caption.copyWith(color: AppColors.inkMuted),
  labelLarge: _button,
  labelMedium: _captionStrong,
  labelSmall: _style(12, FontWeight.w600, 1.0, 0),
);

const _stadium = StadiumBorder();

// 색은 ColorScheme에서 온다. 여기서 색을 정하면 FilledButton.tonal까지
// primary로 칠해지므로 모양과 크기만 정한다.
final _filledStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
  shape: const WidgetStatePropertyAll(_stadium),
  textStyle: WidgetStatePropertyAll(_button),
  elevation: const WidgetStatePropertyAll(0),
);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _colorScheme,
  scaffoldBackgroundColor: AppColors.canvas,
  canvasColor: AppColors.canvas,
  textTheme: _textTheme,
  dividerTheme: const DividerThemeData(
    color: AppColors.dividerSoft,
    thickness: 1,
    space: 1,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.canvas,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: _headline,
  ),
  cardTheme: const CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
    ),
  ),
  listTileTheme: ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    minVerticalPadding: 10,
    titleTextStyle: _bodyStrong,
    subtitleTextStyle: _caption.copyWith(color: AppColors.inkMuted),
    leadingAndTrailingTextStyle: _callout,
    iconColor: AppColors.inkMuted,
  ),
  filledButtonTheme: FilledButtonThemeData(style: _filledStyle),
  elevatedButtonTheme: ElevatedButtonThemeData(style: _filledStyle),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      // 하단 바에서 FilledButton과 나란히 놓이므로 높이를 맞춘다.
      minimumSize: const Size(64, 52),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: _stadium,
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.hairline),
      textStyle: _button,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: _stadium,
      foregroundColor: AppColors.primary,
      textStyle: _bodyStrong,
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: AppColors.ink,
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.cream,
    // 브랜드 그림자는 FAB가 직접 그리지 못해서 captureShadow를 감싸 쓴다.
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 0,
    highlightElevation: 0,
    shape: _stadium,
    extendedSizeConstraints: const BoxConstraints.tightFor(height: 60),
    extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
    extendedTextStyle: _button,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surface,
    selectedColor: AppColors.primary,
    secondarySelectedColor: AppColors.primary,
    labelStyle: _callout,
    secondaryLabelStyle: _callout.copyWith(color: AppColors.onPrimary),
    side: const BorderSide(color: AppColors.hairline),
    shape: _stadium,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    deleteIconColor: AppColors.inkMuted,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: _body.copyWith(color: AppColors.inkMuted),
    border: _inputBorder(AppColors.hairline, 1),
    enabledBorder: _inputBorder(AppColors.hairline, 1),
    focusedBorder: _inputBorder(AppColors.primary, 2),
    errorBorder: _inputBorder(AppColors.error, 2),
    focusedErrorBorder: _inputBorder(AppColors.error, 2),
    errorStyle: _caption.copyWith(color: AppColors.error),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    modalElevation: 0,
    modalBarrierColor: Color(0x661B1830), // scrim 40%
    dragHandleColor: AppColors.hairline,
    dragHandleSize: Size(36, 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
    ),
    titleTextStyle: _headline,
    contentTextStyle: _body,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.hairline),
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    ),
    textStyle: _body,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.ink,
    contentTextStyle: _callout.copyWith(color: AppColors.cream),
    actionTextColor: AppColors.primaryOnDark,
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
  ),
  timePickerTheme: const TimePickerThemeData(
    backgroundColor: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
    ),
  ),
);

OutlineInputBorder _inputBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      borderSide: BorderSide(color: color, width: width),
    );
