import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// PipSpeak Material 3 themes — light & dark.
///
/// Shape language (DESIGN.md): pill-dominant "hyper-rounded" geometry.
/// Buttons, chips, inputs are fully rounded; cards use 24dp; sheets 28-32dp.
abstract final class AppTheme {
  static const double cardRadius = 24;
  static const double sheetRadius = 32;
  static const double pillRadius = 999;

  static ThemeData light() => _base(
    brightness: Brightness.light,
    scaffold: AppColors.canvas,
    card: AppColors.surfaceLowest,
    primary: AppColors.primaryContainer,
    onPrimary: AppColors.onPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inputFill: AppColors.surfaceLow,
    navIndicator: AppColors.secondaryFixed,
  );

  static ThemeData dark() => _base(
    brightness: Brightness.dark,
    scaffold: AppColors.darkCanvas,
    card: AppColors.darkSurface1,
    primary: AppColors.inversePrimary,
    onPrimary: AppColors.navyDeep,
    surface: AppColors.darkCanvas,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkSurface3,
    inputFill: AppColors.darkSurface2,
    navIndicator: AppColors.darkSurface3,
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color primary,
    required Color onPrimary,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color inputFill,
    required Color navIndicator,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme(onSurface);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark
          ? AppColors.darkSurface2
          : AppColors.primaryContainer,
      onPrimaryContainer: isDark
          ? AppColors.inversePrimary
          : AppColors.onPrimaryContainer,
      secondary: isDark ? AppColors.sky : AppColors.secondary,
      onSecondary: isDark ? AppColors.navyDeep : AppColors.onSecondary,
      secondaryContainer: isDark
          ? AppColors.darkSurface3
          : AppColors.secondaryContainer,
      onSecondaryContainer: isDark
          ? AppColors.secondaryFixed
          : AppColors.onSecondaryContainer,
      tertiary: isDark
          ? AppColors.tertiaryFixed
          : AppColors.onTertiaryFixedVariant,
      onTertiary: isDark ? AppColors.navyDeep : AppColors.onTertiary,
      tertiaryContainer: isDark
          ? AppColors.darkSurface2
          : AppColors.tertiaryFixed,
      onTertiaryContainer: isDark
          ? AppColors.tertiaryFixed
          : AppColors.onTertiaryFixedVariant,
      error: isDark ? const Color(0xFFFFB4AB) : AppColors.error,
      onError: isDark ? const Color(0xFF690005) : AppColors.onError,
      errorContainer: isDark
          ? const Color(0xFF5C1410)
          : AppColors.errorContainer,
      onErrorContainer: isDark
          ? AppColors.errorContainer
          : AppColors.onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceContainerLowest: card,
      surfaceContainerLow: isDark
          ? AppColors.darkSurface1
          : AppColors.surfaceLow,
      surfaceContainer: isDark
          ? AppColors.darkSurface2
          : AppColors.surfaceContainer,
      surfaceContainerHigh: isDark
          ? AppColors.darkSurface3
          : AppColors.surfaceHigh,
      surfaceContainerHighest: isDark
          ? AppColors.darkSurface3
          : AppColors.surfaceHighest,
      inversePrimary: AppColors.inversePrimary,
      shadow: AppColors.shadowTint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: scheme.primary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: navIndicator,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: textTheme.labelLarge,
              shape: const StadiumBorder(),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed) ||
                        states.contains(WidgetState.focused)
                    ? scheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              foregroundColor: WidgetStatePropertyAll(scheme.primary),
              side: WidgetStatePropertyAll(BorderSide(color: scheme.primary)),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          borderSide: const BorderSide(color: AppColors.sky, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sheetRadius),
        ),
        titleTextStyle: textTheme.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkSurface2 : AppColors.surfaceHigh,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark
            ? AppColors.darkSurface2
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(pillRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryContainer
              : (isDark ? AppColors.darkSurface3 : AppColors.surfaceHighest),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
