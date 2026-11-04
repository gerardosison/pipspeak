import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/star_level.dart';

/// Stars reward / level-up celebration
/// (Stitch `celebration_stars_earned_level_up`).
/// Business rule: stars only on improvement; level n needs 10*n stars.
class StarsRewardScreen extends ConsumerStatefulWidget {
  const StarsRewardScreen({super.key});

  @override
  ConsumerState<StarsRewardScreen> createState() => _StarsRewardScreenState();
}

class _StarsRewardScreenState extends ConsumerState<StarsRewardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    // Stars were saved once with the session; this screen only shows them.
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final report = ref.watch(lastReportProvider);
    final user =
        ref.watch(currentUserProvider) ?? const UserProfile.placeholder();
    final stars = report?.starsEarned ?? 0;
    final needed = LevelProgress.starsNeeded(user.level);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyDeep, AppColors.primaryContainer],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti-ish star field
              for (var i = 0; i < 14; i++)
                Positioned(
                  left: (i * 97) % 360 + 8.0,
                  top: (i * 151) % 640 + 20.0,
                  child: AnimatedBuilder(
                    animation: _twinkle,
                    builder: (_, _) => Opacity(
                      opacity:
                          0.25 +
                          0.5 *
                              (0.5 +
                                  0.5 *
                                      math.sin(
                                        _twinkle.value * 2 * math.pi + i,
                                      )),
                      child: Icon(
                        Icons.star_rounded,
                        size: 10 + (i % 4) * 5.0,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        // Streak banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${user.streakDays}-day streak!',
                                style: text.labelLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const PipMascot(
                          asset: PipAsset.stars,
                          size: 150,
                          showBadge: true,
                          badgeIcon: Icons.star,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Speech Complete!',
                          style: text.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Earned stars
                        StarRow(count: stars, total: 3, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          '+$stars stars earned',
                          style: text.labelLarge?.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Level progress card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Level ${user.level} Orator',
                                    style: text.labelLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${user.stars}/$needed',
                                    style: text.labelMedium?.copyWith(
                                      color: AppColors.secondaryFixed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (user.stars / needed).clamp(0.0, 1.0),
                                  minHeight: 12,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.gold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (report?.leveledUp ?? false)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.tertiaryFixed.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.tertiaryFixed,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_open,
                                        size: 16,
                                        color: AppColors.tertiaryFixed,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Unlocked: Tougher audience modes!',
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelMedium?.copyWith(
                                            color: AppColors.tertiaryFixed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text(
                                  user.stars == 0
                                      ? 'Complete one more speech to start earning stars'
                                      : '${needed - user.stars} stars to Level ${user.level + 1}',
                                  style: text.bodySmall?.copyWith(
                                    color: AppColors.secondaryFixed,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Back to Home',
                          icon: Icons.home,
                          color: AppColors.secondaryFixed,
                          foreground: AppColors.navy,
                          onPressed: () => context.go(AppRoutes.home),
                        ),
                        const SizedBox(height: 8),
                        PipGhostButton(
                          label: 'View feedback again',
                          color: Colors.white,
                          onPressed: () =>
                              context.push(AppRoutes.sessionReport),
                        ),
                      ],
                    ),
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

/// Stitch `post_practice_keep_going_screen` — supportive state shown when
/// a take doesn't improve. Stars unlock after the next improved speech.
class KeepGoingScreen extends ConsumerWidget {
  const KeepGoingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final firstName = (ref.watch(currentUserProvider)?.nickname ?? 'Speaker')
        .split(' ')
        .first;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Center(
                child: PipMascot(
                  asset: PipAsset.pacing,
                  size: 150,
                  showBadge: true,
                  badgeIcon: Icons.favorite,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Keep going, $firstName!',
                textAlign: TextAlign.center,
                style: text.headlineLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'This take didn\'t beat your last score — so no stars '
                'this time. But you showed up, and that\'s the hardest part.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Try again now',
                icon: Icons.replay,
                onPressed: () =>
                    context.pushReplacement(AppRoutes.practiceLive),
              ),
              const SizedBox(height: 8),
              PipSecondaryButton(
                label: 'Back to Home',
                icon: Icons.home,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
