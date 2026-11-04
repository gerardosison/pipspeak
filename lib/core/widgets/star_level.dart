import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../features/progress/services/level_service.dart';
import 'pip_chips.dart';

/// Level n requires 10*n more stars to reach level n+1 (cumulative).
/// Stars are only earned when a speech improves on the previous one.
class LevelProgress extends StatelessWidget {
  const LevelProgress({
    super.key,
    required this.level,
    required this.stars,
    this.compact = false,
  });

  final int level;
  final int stars;
  final bool compact;

  /// Stars needed to reach the next level from level [level].
  static int starsNeeded(int level) => LevelService.starsNeeded(level);

  @override
  Widget build(BuildContext context) {
    final needed = starsNeeded(level);
    final progress = (stars / needed).clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      child: SizedBox(
        height: 12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: scheme.surfaceContainerHigh),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.amber, AppColors.gold],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return Row(
        children: [
          StarChip(label: 'Lv $level', icon: Icons.military_tech),
          const SizedBox(width: 8),
          Expanded(child: bar),
          const SizedBox(width: 8),
          Text('$stars/$needed', style: text.labelMedium),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const WidgetSpan(
                    child: Icon(
                      Icons.military_tech,
                      color: AppColors.amber,
                      size: 20,
                    ),
                  ),
                  TextSpan(text: ' Level $level Speaker'),
                ],
              ),
              style: text.labelLarge?.copyWith(color: scheme.primary),
            ),
            Text(
              '$stars / $needed stars',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
        const SizedBox(height: 4),
        Text(
          stars == 0
              ? 'Complete one more speech to start earning stars'
              : '${needed - stars} more to Level ${level + 1}',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Row of N star icons (filled gold / outlined).
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.count,
    this.total = 3,
    this.size = 40,
  });

  final int count;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        total,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < count
                ? AppColors.gold
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
