import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'pip_mascot.dart';

/// Friendly empty-state: Pip illustration + title + message + optional CTA.
class PipEmptyState extends StatelessWidget {
  const PipEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.asset = PipAsset.happy,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String title;
  final String message;
  final PipAsset asset;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PipMascot(asset: asset, size: 140),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(color: scheme.primary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: text.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular back button used on secondary screens.
class PipBackButton extends StatelessWidget {
  const PipBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: Icon(Icons.arrow_back_rounded, color: color ?? scheme.primary),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    );
  }
}

/// Simple centered-title app bar in the PipSpeak style.
PreferredSizeWidget pipAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  bool showBack = true,
  VoidCallback? onBack,
  Widget? trailingChip,
  bool? centerTitle,
  TextStyle? titleStyle,
}) {
  final text = Theme.of(context).textTheme;
  final scheme = Theme.of(context).colorScheme;
  return AppBar(
    leading: showBack ? PipBackButton(onPressed: onBack) : null,
    automaticallyImplyLeading: false,
    centerTitle: centerTitle,
    title: Text(title,
        style: titleStyle ?? text.headlineSmall?.copyWith(color: scheme.primary)),
    actions: [
      ...?actions,
      if (trailingChip != null)
        Padding(padding: const EdgeInsets.only(right: 12), child: trailingChip),
    ],
  );
}

/// Consistent list-page scaffold body: max readable width, 16px gutters.
class PipPageBody extends StatelessWidget {
  const PipPageBody({
    super.key,
    required this.children,
    this.spacing = 16,
    this.padding,
    this.maxWidth = 1040,
  });

  final List<Widget> children;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView.separated(
            padding: padding ??
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: children.length,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ),
    );
  }
}

/// Wraps cards into readable columns as space allows, then stacks them on
/// narrow screens. Children keep their natural heights.
class PipResponsiveGrid extends StatelessWidget {
  const PipResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 340,
    this.maxColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: runSpacing),
              children[i],
            ],
          ],
        );
      }

      final columns = ((constraints.maxWidth + spacing) /
              (minItemWidth + spacing))
          .floor()
          .clamp(1, maxColumns)
          .toInt();
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

/// Ambient pastel blobs used behind auth/onboarding screens.
class AmbientBlobs extends StatelessWidget {
  const AmbientBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alpha = isDark ? 0.10 : 0.35;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _Blob(
                size: 260,
                color: scheme.secondaryContainer.withValues(alpha: alpha)),
          ),
          Positioned(
            top: 200,
            right: -90,
            child: _Blob(
                size: 240,
                color: scheme.tertiaryContainer.withValues(alpha: alpha)),
          ),
          Positioned(
            bottom: -80,
            left: 30,
            child: _Blob(
                size: 280,
                color: scheme.secondaryContainer.withValues(alpha: alpha)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)],
      ),
    );
  }
}

/// Theme-aware small pill toggle used in app-bars (dark/light).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.isDark, required this.onToggle});

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: onToggle,
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
          color: scheme.onSurfaceVariant),
    );
  }
}

/// Thin progress bar used for step indicators (Step 1 of 2 etc.).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(
        total,
        (i) => Expanded(
          child: Container(
            height: 8,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: i < step
                  ? scheme.primary
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            ),
          ),
        ),
      ),
    );
  }
}
