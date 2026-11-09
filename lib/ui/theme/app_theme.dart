import 'package:flutter/material.dart';

/// Luminous Alabaster palette.
abstract final class AppColors {
  static const alabaster = Color(0xFFFAF9F6); // page ground
  static const surface = Color(0xFFFFFFFF); // cards
  static const charcoal = Color(0xFF2C2D30); // hero cards, primary buttons
  static const ink = Color(0xFF1B1C1A); // body text
  static const muted = Color(0xFF6B6C70); // secondary text on light
  static const mutedStrong = Color(0xFF45474A); // longer secondary copy
  static const onDarkMuted = Color(0xFFA3A3A7); // secondary text on charcoal
  static const onDarkSoft = Color(0xFFC9C9CC); // body text on charcoal
  static const chip = Color(0xFFEFEEEB); // icon circles, bar tracks
  static const tile = Color(0xFFF2F0EB); // inset tiles, selected rows
  static const sand = Color(0xFFE6E2DC); // decorative ovals, borders
  static const sandDeep = Color(0xFFD4CEBE);
  static const mint = Color(0xFF9FDDB8); // innate accent on charcoal

  static const softShadow = [
    BoxShadow(
      color: Color(0x0D2C2D30), // 5%
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];
  static const liftShadow = [
    BoxShadow(
      color: Color(0x2E2C2D30), // 18%
      offset: Offset(0, 24),
      blurRadius: 48,
      spreadRadius: -12,
    ),
  ];
}

/// Text styles. The fonts are variable, so each style sets the 'wght' axis as
/// well as [FontWeight] — Flutter doesn't map one to the other by itself.
abstract final class AppText {
  static TextStyle manrope(
    double size, {
    int weight = 400,
    double? height,
    double letterSpacing = 0,
    Color? color,
  }) => _style('Manrope', size, weight, height, letterSpacing, color);

  static TextStyle inter(
    double size, {
    int weight = 400,
    double? height,
    double letterSpacing = 0,
    Color? color,
  }) => _style('Inter', size, weight, height, letterSpacing, color);

  /// Small all-caps label, e.g. "STARTING IN".
  static TextStyle caps({Color color = AppColors.muted}) =>
      inter(10, weight: 600, height: 1.4, letterSpacing: 1.2, color: color);

  /// Big light numbers and names, e.g. a city or talent on a hero card.
  static TextStyle display(double size, {Color? color}) => manrope(
    size,
    weight: 300,
    height: 1.2,
    letterSpacing: -size * 0.03,
    color: color,
  );

  static TextStyle _style(
    String family,
    double size,
    int weight,
    double? height,
    double letterSpacing,
    Color? color,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.charcoal,
    onPrimary: Colors.white,
    secondary: AppColors.charcoal,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.sand,
    outlineVariant: AppColors.chip,
  );

  final pillShape = WidgetStatePropertyAll<OutlinedBorder>(
    const StadiumBorder(),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.alabaster,
    fontFamily: 'Inter',
    textTheme: TextTheme(
      headlineMedium: AppText.display(32, color: AppColors.ink),
      headlineSmall: AppText.manrope(24, weight: 600, color: AppColors.ink),
      titleLarge: AppText.manrope(18, weight: 600, color: AppColors.ink),
      titleMedium: AppText.inter(16, weight: 600, color: AppColors.ink),
      titleSmall: AppText.inter(14, weight: 600, color: AppColors.ink),
      bodyLarge: AppText.inter(16, height: 1.5, color: AppColors.ink),
      bodyMedium: AppText.inter(14, height: 1.43, color: AppColors.mutedStrong),
      bodySmall: AppText.inter(12, height: 1.33, color: AppColors.muted),
      labelLarge: AppText.inter(16, weight: 600),
      labelMedium: AppText.caps(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.charcoal.withValues(alpha: 0.6)
              : AppColors.charcoal,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
        shape: pillShape,
        textStyle: WidgetStatePropertyAll(AppText.inter(16, weight: 600)),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
        shape: pillShape,
        textStyle: WidgetStatePropertyAll(AppText.inter(14, weight: 600)),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.ink, size: 20),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.charcoal,
      linearTrackColor: AppColors.chip,
    ),
  );
}
