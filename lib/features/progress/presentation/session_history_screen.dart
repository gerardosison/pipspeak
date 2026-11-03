import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';

/// Full session-history list; tapping a row opens the Rehearsal
/// Analysis detail. No dedicated Stitch design — reuses the progress
/// history card style.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: pipAppBar(context, title: 'Session History'),
      body: history.isEmpty
          ? PipEmptyState(
              title: 'No sessions yet',
              message:
                  'Finish your first rehearsal and it will show up here.',
              asset: PipAsset.pacing,
              actionLabel: 'Start practicing',
              actionIcon: Icons.mic_rounded,
              onAction: () => context.go(AppRoutes.practiceSetup),
            )
          : PipPageBody(
              maxWidth: 1120,
              children: [
                PipResponsiveGrid(
                  minItemWidth: 420,
                  maxColumns: 2,
                  children: [
                    for (final s in history) _row(context, s, text, scheme),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, PracticeSession s, TextTheme text,
      ColorScheme scheme) {
    final mins = s.duration.inMinutes;
    final secs = s.duration.inSeconds % 60;
    return PipCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(AppRoutes.rehearsalAnalysis, extra: s),
      child: Row(children: [
        IconDisc(
            icon: s.improved ? Icons.trending_up : Icons.trending_flat,
            background: s.improved
                ? AppColors.tertiaryFixed.withValues(alpha: 0.6)
                : scheme.surfaceContainerHigh),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: 2),
            Text(
              '${DateFormat.yMMMd().format(s.date)} • '
              '$mins:${secs.toString().padLeft(2, '0')} • '
              '${s.avgWpm} wpm • ${s.fillerCount} fillers',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        s.starsEarned > 0
            ? StarChip(label: '+${s.starsEarned}')
            : PipBadge(
                label: '—',
                background: scheme.surfaceContainerHigh,
                foreground: scheme.onSurfaceVariant),
      ]),
    );
  }
}
