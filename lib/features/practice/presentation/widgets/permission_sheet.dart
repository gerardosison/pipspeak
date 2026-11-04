import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/pip_buttons.dart';
import '../../../../core/widgets/pip_mascot.dart';

/// Camera + mic permission modal (Stitch `permission_modal`).
/// Returns true when granted.
Future<bool> showPipPermissionSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PermissionSheet(),
  );
  return result ?? false;
}

class _PermissionSheet extends ConsumerWidget {
  const _PermissionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.sheetRadius),
        boxShadow: AppColors.cardShadow(3),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            const PipMascot(
              asset: PipAsset.camera,
              size: 110,
              showBadge: true,
              badgeIcon: Icons.mic,
            ),
            const SizedBox(height: 16),
            Text(
              'Lights, camera… almost!',
              style: text.headlineMedium?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Pip needs your camera & mic to coach body alignment, gestures, '
              'pace and filler words live.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _permChip(Icons.videocam_outlined, 'Posture'),
                const SizedBox(width: 8),
                _permChip(Icons.graphic_eq, 'Audio'),
                const SizedBox(width: 8),
                _permChip(Icons.lock_outline, 'On-device'),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Allow Camera & Mic',
              icon: Icons.verified_user,
              onPressed: () async {
                final ok = await ref
                    .read(permissionServiceProvider)
                    .requestCameraAndMic();
                if (context.mounted) Navigator.of(context).pop(ok);
              },
            ),
            const SizedBox(height: 8),
            PipGhostButton(
              label: 'Not now',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 4),
            Text(
              'Audio & video never leave your device.',
              style: text.labelSmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.secondaryFixed.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryFixedVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
