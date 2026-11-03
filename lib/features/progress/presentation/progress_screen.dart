import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';
import '../../../core/widgets/star_level.dart';

/// Progress tab — segmented Growth / Milestones views combining the two
/// Stitch variants (`progress_growth_1`, `progress_growth_2`).
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _view = 0; // 0 = Growth, 1 = Milestones

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user =
        ref.watch(currentUserProvider) ?? const UserProfile.placeholder();
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'Progress',
        showBack: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StarChip(
              label: '${ref.watch(levelStatusProvider).totalStars}',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Segmented Growth / Milestones
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                  child: Row(
                    children: [
                      _seg('Growth', 0, scheme),
                      _seg('Milestones', 1, scheme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_view == 0)
                  _growthView(user, history, text, scheme)
                else
                  _milestonesView(user, text, scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(String label, int index, ColorScheme scheme) {
    final sel = _view == index;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        selected: sel,
        button: true,
        label: '$label view',
        child: InkWell(
          onTap: () => setState(() => _view = index),
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? scheme.primary : null,
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
            ),
            child: Center(
              child: Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------- progress_growth_2
  Widget _growthView(
    UserProfile user,
    List<PracticeSession> history,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final needed = LevelProgress.starsNeeded(user.level);
    final levelCard = PipCard(
      child: Column(
        children: [
          Row(
            children: [
              const PipMascot(
                asset: PipAsset.stars,
                size: 88,
                showBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${user.level} Orator',
                      style: text.headlineMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      'Practice Hero rank',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StarChip(
                          label:
                              '${ref.watch(levelStatusProvider).totalStars} stars',
                        ),
                        PipBadge(
                          label: '${user.streakDays}d streak',
                          icon: Icons.local_fire_department,
                          background: AppColors.tertiaryFixed,
                          foreground: AppColors.onTertiaryFixed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LevelProgress(level: user.level, stars: user.stars),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${needed - user.stars} more star(s) to Level ${user.level + 1}. '
              'Level n needs 10 × n stars; your first speech per goal is a '
              'baseline, and later speeches earn 1–3 stars for improving on '
              'your recent average score (+2, +5, +10 points).',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
    final achievements = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Achievements'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge('First Speech', Icons.mic, user.totalSessions > 0),
            _badge(
              '3-Day Streak',
              Icons.local_fire_department,
              user.streakDays >= 3,
            ),
            _badge(
              'Pace Pro',
              Icons.speed,
              history.any((s) => s.avgWpm >= 130 && s.avgWpm <= 150),
            ),
            _badge(
              'Filler Slayer',
              Icons.bubble_chart,
              history.any((s) => s.fillerCount == 0),
            ),
            _badge('Level 5', Icons.military_tech, user.level >= 5),
          ],
        ),
      ],
    );
    final recentPractice = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent practice',
          action: history.isEmpty ? null : 'View all',
          onAction: () => context.push(AppRoutes.history),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          PipEmptyState(
            title: 'No practice sessions yet',
            message:
                'Your first rehearsal will add pace, filler word, and posture insights here.',
            asset: PipAsset.pacing,
            actionLabel: 'Start practicing',
            actionIcon: Icons.mic_rounded,
            onAction: () => context.go(AppRoutes.practiceSetup),
          )
        else
          for (final s in history.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _historyCard(s, text, scheme),
            ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              levelCard,
              const SizedBox(height: 16),
              achievements,
              const SizedBox(height: 16),
              recentPractice,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  levelCard,
                  const SizedBox(height: 20),
                  achievements,
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: recentPractice),
          ],
        );
      },
    );
  }

  // ------------------------------------------------- progress_growth_1
  Widget _milestonesView(UserProfile user, TextTheme text, ColorScheme scheme) {
    final milestones = [
      ('First rehearsal', 'Complete your first practice', user.totalSessions > 0),
      (
        'Earn a star',
        'Improve on a previous speech',
        ref.watch(levelStatusProvider).totalStars > 0,
      ),
      ('10 speeches', 'Reach double digits', user.totalSessions >= 10),
      ('Week-long streak', '7 days in a row', user.streakDays >= 7),
      ('Level 5 Orator', 'Reach 100 total stars', user.level >= 5),
    ];
    return Column(
      children: [
        // Hero mascot card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryContainer, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Row(
            children: [
              const PipMascot(
                asset: PipAsset.stage,
                size: 90,
                showBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.totalSessions == 0
                          ? 'Your journey starts here'
                          : 'You\'re on a roll!',
                      style: text.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.totalSessions} speeches • ${ref.watch(levelStatusProvider).totalStars} stars • '
                      '${user.streakDays}-day streak',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.secondaryFixed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Milestones'),
        const SizedBox(height: 8),
        PipResponsiveGrid(
          minItemWidth: 420,
          maxColumns: 2,
          runSpacing: 10,
          children: [
            for (var i = 0; i < milestones.length; i++)
              PipCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: milestones[i].$3
                          ? AppColors.tertiaryFixed
                          : scheme.surfaceContainerHigh,
                    ),
                    child: Icon(
                      milestones[i].$3
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: milestones[i].$3
                          ? AppColors.onTertiaryFixed
                          : scheme.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestones[i].$1,
                          style: text.labelLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          milestones[i].$2,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (milestones[i].$3)
                    const MintBadge(label: 'Done', icon: Icons.check),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(String label, IconData icon, bool earned) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: earned ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: earned
              ? AppColors.gold.withValues(alpha: 0.25)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          border: Border.all(
            color: earned
                ? AppColors.gold
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: earned ? AppColors.amber : scheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: text.labelMedium?.copyWith(
                color: earned ? scheme.onSurface : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(PracticeSession s, TextTheme text, ColorScheme scheme) {
    final mins = s.duration.inMinutes;
    final secs = s.duration.inSeconds % 60;
    return PipCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(AppRoutes.rehearsalAnalysis, extra: s),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.paceScore > 75
                  ? AppColors.tertiaryFixed.withValues(alpha: 0.6)
                  : AppColors.secondaryFixed.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Text(
                '${s.paceScore}',
                style: text.labelLarge?.copyWith(color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat.MMMd().format(s.date)} • '
                  '$mins:${secs.toString().padLeft(2, '0')} • ${s.avgWpm} wpm',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (s.improved)
                      const MintBadge(
                        label: 'Improved',
                        icon: Icons.trending_up,
                      )
                    else
                      PipBadge(
                        label: 'Off day',
                        background: scheme.surfaceContainerHigh,
                        foreground: scheme.onSurfaceVariant,
                      ),
                    if (s.starsEarned > 0) StarChip(label: '+${s.starsEarned}'),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.outline),
        ],
      ),
    );
  }
}
