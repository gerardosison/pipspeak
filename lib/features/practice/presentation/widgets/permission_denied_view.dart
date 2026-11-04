import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/pip_buttons.dart';
import '../../../../core/widgets/pip_mascot.dart';
import '../../../../core/widgets/pip_misc.dart';

/// Permission-denied fallback (no Stitch design — matching style).
/// Offers retry, "continue with mic only" and a link back to setup.
class PermissionDeniedView extends ConsumerWidget {
  const PermissionDeniedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: pipAppBar(context, title: 'Permissions'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Center(
                child: PipMascot(
                  asset: PipAsset.sad,
                  size: 140,
                  showBadge: true,
                  badgeIcon: Icons.videocam_off,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No camera? No problem.',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Without camera & mic access, Pip can\'t watch or listen '
                'live. You can still rehearse with the teleprompter — '
                'or grant access anytime in Settings.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: AppColors.cardShadow(1),
                ),
                child: Column(
                  children: [
                    for (final (icon, title, sub) in [
                      (Icons.mic_none, 'Mic only', 'Pace & filler feedback'),
                      (Icons.subtitles, 'Teleprompter', 'Practice with cues'),
                      (
                        Icons.settings_outlined,
                        'System settings',
                        'Grant access to unlock full coaching',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(icon, size: 22, color: AppColors.secondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: text.labelLarge?.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    sub,
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Open Settings',
                icon: Icons.settings,
                onPressed: () async {
                  var opened = false;
                  try {
                    opened = await ref
                        .read(permissionServiceProvider)
                        .openSettings();
                  } catch (_) {}
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'In Chrome, use the site controls beside the address bar to allow camera and microphone. On your phone, open Settings → Apps → PipSpeak → Permissions.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              PipSecondaryButton(
                label: 'Return to camera and mic setup',
                icon: Icons.subtitles,
                onPressed: () => context.go(AppRoutes.practiceSetup),
              ),
              const SizedBox(height: 4),
              PipGhostButton(
                label: 'Back to setup',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
