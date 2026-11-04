import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// Material action with keyboard/focus support and a contrasting label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.color,
    this.foreground,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final Color? color;
  final Color? foreground;

  static Color foregroundFor(Color background) {
    final luminance = background.computeLuminance();
    final darkContrast =
        (luminance + 0.05) / (AppColors.navyDeep.computeLuminance() + 0.05);
    final lightContrast = 1.05 / (luminance + 0.05);
    return darkContrast >= lightContrast ? AppColors.navyDeep : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.primary;
    final textColor =
        foreground ??
        (color == null ? scheme.onPrimary : foregroundFor(background));
    return SizedBox(
      width: expanded ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppColors.buttonPressShadow.withValues(alpha: 0.35),
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: textColor,
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
