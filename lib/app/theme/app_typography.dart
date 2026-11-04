import 'package:flutter/material.dart';

/// Shared PipSpeak type scale for light and dark themes.
abstract final class AppTypography {
  static TextTheme textTheme(Color color) {
    final base = TextStyle(color: color);
    final body = TextStyle(color: color);
    return TextTheme(
      displayLarge: base.copyWith(
        fontSize: 34,
        height: 42 / 34,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.68,
      ),
      displaySmall: base.copyWith(
        fontSize: 34,
        height: 42 / 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.68,
      ),
      headlineLarge: base.copyWith(
        fontSize: 26,
        height: 34 / 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.26,
      ),
      headlineMedium: base.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: body.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: body.copyWith(fontSize: 14, height: 20 / 14),
      bodySmall: body.copyWith(fontSize: 12, height: 16 / 12),
      labelLarge: body.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.14,
      ),
      labelMedium: body.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.24,
      ),
      labelSmall: body.copyWith(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.33,
      ),
    );
  }
}
