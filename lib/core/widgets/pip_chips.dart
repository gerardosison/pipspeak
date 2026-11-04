import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// Ultra-chunky pill badge (32px tall, per DESIGN.md "Chips & Pill Badges").
class PipBadge extends StatelessWidget {
  const PipBadge({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.dot = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  /// Show a small pulsing-style dot instead of an icon.
  final bool dot;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSecondaryContainer;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            )
          else if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mint "optimal / success" badge.
class MintBadge extends StatelessWidget {
  const MintBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => PipBadge(
    label: label,
    icon: icon,
    background: AppColors.tertiaryFixed,
    foreground: AppColors.onTertiaryFixedVariant,
  );
}

/// Sky "info" badge.
class SkyBadge extends StatelessWidget {
  const SkyBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => PipBadge(
    label: label,
    icon: icon,
    background: AppColors.secondaryFixed,
    foreground: AppColors.onSecondaryFixedVariant,
  );
}

/// Gold achievement chip — reserved for stars / streaks / XP (DESIGN.md rule).
class StarChip extends StatelessWidget {
  const StarChip({super.key, required this.label, this.icon = Icons.star});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => PipBadge(
    label: label,
    icon: icon,
    background: AppColors.gold,
    foreground: AppColors.navy,
  );
}

/// Small circular selectable chip used for options (languages, goals…).
class PipOptionChip extends StatelessWidget {
  const PipOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
