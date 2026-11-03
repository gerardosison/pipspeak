import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_misc.dart';

/// Privacy & Data — expands the Settings privacy section.
/// No Stitch design; matching style.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: pipAppBar(context, title: 'Privacy & Data'),
      body: PipPageBody(maxWidth: 760, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: AppColors.tertiaryFixed),
          ),
          child: Column(children: [
            const Icon(Icons.lock, size: 40, color: AppColors.onTertiaryFixed),
            const SizedBox(height: 10),
            Text('100% On-Device',
                style: text.headlineMedium
                    ?.copyWith(color: AppColors.onTertiaryFixed)),
            const SizedBox(height: 6),
            Text(
              'Your voice, face and scripts are analyzed locally. '
              'Nothing leaves this phone.',
              textAlign: TextAlign.center,
              style: text.bodyMedium
                  ?.copyWith(color: AppColors.onTertiaryFixedVariant),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        PipCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('On-device speech analysis',
                  style: text.labelLarge
                      ?.copyWith(color: scheme.onSurface)),
              subtitle: Text('Whisper + pose models run locally',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              value: true,
              onChanged: (_) {},
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Save practice recordings',
                  style: text.labelLarge
                      ?.copyWith(color: scheme.onSurface)),
              subtitle: Text('Keep audio for later review',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              value: true,
              onChanged: (_) {},
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Anonymous usage stats',
                  style: text.labelLarge
                      ?.copyWith(color: scheme.onSurface)),
              subtitle: Text('Helps improve Pip — optional',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              value: false,
              onChanged: (_) {},
            ),
          ]),
        ),
        const SizedBox(height: 4),
        PipCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Data retention',
                  style:
                      text.labelLarge?.copyWith(color: scheme.onSurface)),
              const SizedBox(width: 8),
              const SkyBadge(label: 'Keep 30 days'),
            ]),
            const SizedBox(height: 10),
            for (final r in [
              'Practice recordings are auto-deleted after 30 days.',
              'Transcripts are stored locally and never synced.',
              'Deleting your account wipes everything instantly.',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18,
                          color: AppColors.onTertiaryFixedVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r,
                            style: text.bodyMedium
                                ?.copyWith(color: scheme.onSurface)),
                      ),
                    ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
