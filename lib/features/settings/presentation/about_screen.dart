import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';

/// About PipSpeak — mascot hero, app story, hackathon/team credits,
/// open-source stack (Stitch `about_pipspeak`).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _team = [
    ('LD', 'Lead Oratory Designer', 'UX & Gamification'),
    ('MC', 'ML Cadence Engineer', 'Acoustics & VAD'),
    ('FA', 'Frontend Architect', 'Android & M3'),
    ('SC', 'Speech Coach Advisor', 'Pedagogy & Drills'),
  ];

  static const _stack = [
    (Icons.graphic_eq, 'Whisper', 'On-device speech-to-text'),
    (Icons.front_hand, 'Google ML Kit', 'On-device body landmarks'),
    (Icons.flutter_dash, 'Flutter', 'Material 3 UI toolkit'),
    (Icons.psychology, 'On-device LLM', 'Feedback generation'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'About PipSpeak',
        actions: [
          IconButton(
            tooltip: 'Share PipSpeak',
            icon: Icon(Icons.share, color: scheme.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Hero
                Column(
                  children: [
                    const PipMascot(
                      asset: PipAsset.happy,
                      size: 130,
                      showBadge: true,
                      badgeIcon: Icons.mic,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'PipSpeak',
                      style: text.displayLarge?.copyWith(
                        fontSize: 34,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      'Your Personal AI Oratory & Speech Coach',
                      style: text.bodyLarge?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Version 2.4 (Build 2024.10) • HawkaBuild Edition',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Story card
                PipCard(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconDisc(icon: Icons.auto_awesome, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Empowering Student Voices',
                                  style: text.labelLarge?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PipSpeak helps students build confidence, '
                                  'eliminate filler words and master pacing '
                                  'through friendly real-time AI rehearsals — '
                                  'powered entirely on-device.',
                                  style: text.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _mini(context, Icons.timer, 'Pacing Coach'),
                          const SizedBox(width: 8),
                          _mini(
                            context,
                            Icons.accessibility_new,
                            'Body Alignment',
                          ),
                          const SizedBox(width: 8),
                          _mini(context, Icons.lock, 'On-device AI'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Hackathon banner
                _SectionHeader(
                  'HACKATHON & TEAM',
                  trailing: const SkyBadge(label: 'Special Edition'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryContainer, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: AppColors.secondaryFixed,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'AppBuildersPH Hackathon',
                                  style: text.labelMedium?.copyWith(
                                    color: AppColors.secondaryFixed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'HawkaBuild 2024 Showcase',
                              style: text.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Built in 48 hours to democratize speech '
                              'coaching.',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.secondaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.stars,
                        size: 40,
                        color: AppColors.secondaryFixed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Team grid
                PipCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT CREATED BY',
                        style: text.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'The Oratory Collective / Team HawkaBuild',
                        style: text.labelLarge?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.4,
                        children: [
                          for (final t in _team)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: AppColors.secondaryFixed,
                                    child: Text(
                                      t.$1,
                                      style: text.labelSmall?.copyWith(
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          t.$2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelSmall?.copyWith(
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          t.$3,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.bodySmall?.copyWith(
                                            fontSize: 10,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tech stack
                const _SectionHeader('POWERED BY OPEN SOURCE'),
                const SizedBox(height: 8),
                for (final s in _stack)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PipCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          IconDisc(icon: s.$1, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.$2,
                                  style: text.labelLarge?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  s.$3,
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Made with 💙 for student voices',
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, IconData icon, String label) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
