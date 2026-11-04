import 'package:flutter/material.dart';

/// PipSpeak design tokens, extracted from the Stitch HTML/CSS + DESIGN.md.
///
/// Brand story: deep navy authority, sky-blue + mint pastels for interactive
/// warmth, and gold STRICTLY reserved for stars/achievements.
abstract final class AppColors {
  static Color primaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color brandForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.primary
      : navy;

  static Color accentForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.primary
      : blue;

  // ---------------------------------------------------------------- Brand
  /// Deep navy — primary buttons, headlines, active nav markers.
  static const Color navy = Color(0xFF1B2A6B);

  /// Darkest navy — M3 `primary` role / button press shadow.
  static const Color navyDeep = Color(0xFF001256);

  /// Sky blue — secondary actions, waveforms, banners.
  static const Color sky = Color(0xFF8EC9F5);

  /// Mint green — pacing indicators, success, completed states.
  static const Color mint = Color(0xFFA8E6B8);

  /// Achievement gold — stars, streaks, XP only.
  static const Color gold = Color(0xFFFFD166);
  static const Color amber = Color(0xFFF5A623);

  // Compatibility names used by screens introduced in the frontend merge.
  // They intentionally map to the same brand palette above.
  static const Color ink = onSurface;
  static const Color paper = canvas;
  static const Color line = outlineVariant;
  static const Color blue = primaryContainer;
  static const Color coral = error;
  static const Color yellow = gold;
  static const Color navySoft = onSurfaceVariant;

  // ------------------------------------------------- M3 palette (light)
  static const Color primary = navyDeep;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = navy;
  static const Color onPrimaryContainer = Color(0xFF8694DB);
  static const Color primaryFixed = Color(0xFFDDE1FF);
  static const Color primaryFixedDim = Color(0xFFB9C3FF);
  static const Color onPrimaryFixed = Color(0xFF001257);
  static const Color onPrimaryFixedVariant = Color(0xFF344283);

  static const Color secondary = Color(0xFF21648B);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF98D3FF);
  static const Color onSecondaryContainer = Color(0xFF135B82);
  static const Color secondaryFixed = Color(0xFFC9E6FF);
  static const Color secondaryFixedDim = Color(0xFF92CDF9);
  static const Color onSecondaryFixed = Color(0xFF001E2F);
  static const Color onSecondaryFixedVariant = Color(0xFF004B6F);

  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryFixed = Color(0xFFB2F1C2);
  static const Color tertiaryFixedDim = Color(0xFF97D4A8);
  static const Color onTertiaryFixed = Color(0xFF00210E);
  static const Color onTertiaryFixedVariant = Color(0xFF14512F);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ------------------------------------------------------- Light surfaces
  /// Canvas background (DESIGN.md Level 0).
  static const Color canvas = Color(0xFFF4F6FC);
  static const Color surface = Color(0xFFF7F9FF);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFF1F3F9);
  static const Color surfaceContainer = Color(0xFFECEEF4);
  static const Color surfaceHigh = Color(0xFFE6E8EE);
  static const Color surfaceHighest = Color(0xFFE0E2E8);
  static const Color onSurface = Color(0xFF181C20);
  static const Color onSurfaceVariant = Color(0xFF454650);
  static const Color outline = Color(0xFF767681);
  static const Color outlineVariant = Color(0xFFC6C5D2);
  static const Color inversePrimary = Color(0xFFB9C3FF);
  static const Color inverseOnSurface = Color(0xFFEFF1F7);

  // -------------------------------------------------------- Dark surfaces
  /// Deep abyssal navy canvas (DESIGN.md dark Level 0).
  static const Color darkCanvas = Color(0xFF0E1633);
  static const Color darkSurface1 = Color(0xFF162044);
  static const Color darkSurface2 = Color(0xFF1E2B58);
  static const Color darkSurface3 = Color(0xFF26366E);
  static const Color darkOnSurface = Color(0xFFEFF1F7);
  static const Color darkOnSurfaceVariant = Color(0xFFADB6E0);
  static const Color darkOutline = Color(0xFF7C85B8);

  // ------------------------------------------------------------- Elevation
  static const Color shadowTint = Color(0xFF1B2A6B);
  static const Color buttonPressShadow = Color(0xFF0B1538);

  static List<BoxShadow> cardShadow(int level) => switch (level) {
    2 => const [
      BoxShadow(
        color: Color.fromRGBO(27, 42, 107, 0.09),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
    3 => const [
      BoxShadow(
        color: Color.fromRGBO(27, 42, 107, 0.14),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    _ => const [
      BoxShadow(
        color: Color.fromRGBO(27, 42, 107, 0.06),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  };
}
