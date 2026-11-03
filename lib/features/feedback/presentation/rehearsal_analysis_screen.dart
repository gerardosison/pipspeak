import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_misc.dart';

/// Rehearsal analysis — overall score, Delivery/Topic tabs, weak-section
/// callouts, re-practice & export actions
/// (Stitch `speech_feedback_analysis`). Doubles as Session Detail.
class RehearsalAnalysisScreen extends ConsumerStatefulWidget {
  const RehearsalAnalysisScreen({super.key, this.session});

  /// When pushed from history, the session to display; null → latest report.
  final PracticeSession? session;

  @override
  ConsumerState<RehearsalAnalysisScreen> createState() =>
      _RehearsalAnalysisScreenState();
}

class _RehearsalAnalysisScreenState
    extends ConsumerState<RehearsalAnalysisScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(sessionHistoryProvider);
    if (widget.session == null && history.isEmpty) {
      return Scaffold(
        appBar: pipAppBar(context, title: 'Rehearsal Analysis'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No saved practice results yet. Complete a practice session to see your measured feedback.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final session = widget.session ?? history.first;
    final report = ref.watch(sessionReportProvider(session.id)).valueOrNull;
    // A history entry must use its own saved measurements, never the last
    // in-memory camera session, which may belong to a different practice.
    final matchingRecords =
        (ref.watch(practiceRecordsProvider).valueOrNull ?? []).where(
          (record) => record.id == session.id,
        );
    final savedRecord = matchingRecords.isEmpty ? null : matchingRecords.first;
    final posture = savedRecord?.postureScore;
    final swayPercent = savedRecord?.bodySwayCm == null
        ? null
        : savedRecord!.bodySwayCm! /
              2.0; // Legacy proxy = normalized sway × 200.

    final score = session.paceScore;
    final mins = session.duration.inMinutes;
    final secs = session.duration.inSeconds % 60;

    return Scaffold(
      appBar: pipAppBar(context, title: 'Rehearsal Analysis'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Header card
                PipCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  style: text.headlineSmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat.yMMMd().format(session.date)} • '
                                  '$mins:${secs.toString().padLeft(2, '0')} min',
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _scoreRing(score),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (session.improved)
                            const MintBadge(
                              label: 'Improved',
                              icon: Icons.trending_up,
                            )
                          else
                            PipBadge(
                              label: 'Off day',
                              icon: Icons.trending_flat,
                              background: scheme.surfaceContainerHigh,
                              foreground: scheme.onSurfaceVariant,
                            ),
                          const SizedBox(width: 8),
                          if (session.goal != null)
                            SkyBadge(
                              label: session.goal!,
                              icon: Icons.flag_outlined,
                            ),
                          const Spacer(),
                          if (session.starsEarned > 0)
                            StarChip(label: '+${session.starsEarned}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery / Topic tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                  child: Row(
                    children: [
                      _segTab('Delivery', 0, scheme),
                      _segTab('Topic fit', 1, scheme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_tab == 0) ...[
                  _metricBar(
                    'Pace',
                    session.avgWpm / 180,
                    '${session.avgWpm} wpm',
                    AppColors.secondaryFixed,
                    session.avgWpm > 155 ? 'Slightly fast' : 'In the zone',
                  ),
                  const SizedBox(height: 10),
                  _metricBar(
                    'Fillers',
                    session.fillerCount / 15,
                    '${session.fillerCount} words',
                    session.fillerCount > 8
                        ? AppColors.errorContainer
                        : AppColors.tertiaryFixed,
                    session.fillerCount > 8
                        ? 'Trim "um" & "like"'
                        : 'Clean delivery',
                  ),
                  const SizedBox(height: 10),
                  _metricBar(
                    'Body alignment',
                    (posture ?? 0) / 100,
                    posture == null ? 'Unavailable' : '${posture.round()}/100',
                    AppColors.secondaryContainer,
                    posture == null ? 'No saved camera measurement' : 'Saved camera-based heuristic; eye contact is not measured',
                  ),
                  const SizedBox(height: 10),
                  _metricBar(
                    'Torso variation',
                    ((swayPercent ?? 0) / 7.5).clamp(0.0, 1.0),
                    swayPercent == null
                        ? 'Unavailable'
                        : '${swayPercent.toStringAsFixed(1)}% frame width',
                    AppColors.tertiaryFixed,
                    swayPercent == null ? 'No saved camera measurement' : 'Image-relative estimate; camera movement affects this value',
                  ),
                ] else ...[
                  if (report == null ||
                      (report.strengths.isEmpty && report.improvements.isEmpty))
                    const Text('No topic feedback returned for this session.')
                  else ...[
                    for (final item in report.strengths)
                      _sectionRow(item.title, 100, item.actionableTip),
                    for (final item in report.improvements)
                      _sectionRow(item.title, 50, item.actionableTip),
                  ],
                ],

                const SizedBox(height: 16),
                // Evidence based summary from local rules and Qwen.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(color: AppColors.secondaryFixed),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.flag_circle,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report?.llmResponse?.isNotEmpty == true
                              ? report!.llmResponse!
                              : report?.summary ?? 'Wala pang local AI feedback para sa session na ito.',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.onSecondaryFixedVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Re-practice this speech',
                  icon: Icons.replay,
                  onPressed: () => context.push(AppRoutes.practiceSetup),
                ),
                const SizedBox(height: 8),
                PipSecondaryButton(
                  label: 'Export feedback',
                  icon: Icons.ios_share,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export coming soon (mock)')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segTab(String label, int index, ColorScheme scheme) {
    final sel = _tab == index;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        selected: sel,
        button: true,
        label: label,
        child: InkWell(
          onTap: () => setState(() => _tab = index),
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? scheme.surfaceContainerLowest : null,
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              boxShadow: sel
                  ? const [
                      BoxShadow(
                        color: Color.fromRGBO(27, 42, 107, 0.1),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: sel ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreRing(int score) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: scheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(
              score > 75 ? AppColors.onTertiaryFixedVariant : AppColors.amber,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: text.headlineSmall?.copyWith(color: scheme.primary),
              ),
              Text(
                'SCORE',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBar(
    String label,
    double progress,
    String value,
    Color tint,
    String verdict,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return PipCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: text.labelLarge?.copyWith(color: scheme.onSurface),
              ),
              Text(
                value,
                style: text.labelMedium?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: scheme.surfaceContainerHigh),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: tint),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            verdict,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionRow(String name, int score, String note) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PipCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.labelLarge?.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: score > 75
                    ? AppColors.tertiaryFixed.withValues(alpha: 0.6)
                    : AppColors.errorContainer,
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: text.labelLarge?.copyWith(
                    color: score > 75
                        ? AppColors.onTertiaryFixed
                        : AppColors.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
