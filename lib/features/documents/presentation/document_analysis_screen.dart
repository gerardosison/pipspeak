import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';

/// Document Analysis Result — metadata, section scores, strengths,
/// gaps, tips + "Practice this speech" CTA
/// (Stitch `speech_script_analysis`).
class ScriptAnalysisScreen extends ConsumerWidget {
  const ScriptAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final doc = ref.watch(lastDocAnalysisProvider);

    if (doc == null) {
      return Scaffold(
        appBar: pipAppBar(context, title: 'Script Analysis'),
        body: PipEmptyState(
          title: 'No script analyzed',
          message: 'Upload a script first to see its breakdown here.',
          asset: PipAsset.analysis,
          actionLabel: 'Upload a script',
          actionIcon: Icons.upload_file,
          onAction: () => context.go(AppRoutes.documentUpload),
        ),
      );
    }

    return Scaffold(
      appBar: pipAppBar(context, title: 'Script Analysis'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Metadata card
                PipCard(
                  child: Row(
                    children: [
                      const IconDisc(
                        icon: Icons.description_outlined,
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${doc.wordCount} words • ~${doc.estimatedMinutes} min read',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                      const PipBadge(
                        label: 'On-device Qwen',
                        icon: Icons.offline_bolt_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (doc.keySections.isNotEmpty) ...[
                  Text(doc.keySections.join('\n'), style: text.bodySmall),
                  const SizedBox(height: 12),
                ],
                PipResponsiveGrid(
                  minItemWidth: 420,
                  maxColumns: 2,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Covered topics'),
                        const SizedBox(height: 8),
                        PipCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final s in doc.coveredTopics)
                                _bulletRow(
                                  context,
                                  Icons.check_circle,
                                  AppColors.tertiaryFixed,
                                  s,
                                ),
                              if (doc.coveredTopics.isEmpty)
                                const Text(
                                  'Walang covered topics na naibalik ng model.',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Gaps to fix'),
                        const SizedBox(height: 8),
                        PipCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final s in doc.missingOrWeakTopics)
                                _bulletRow(
                                  context,
                                  Icons.lightbulb,
                                  AppColors.secondaryFixed,
                                  s,
                                ),
                              for (final s in doc.speechImprovements)
                                _bulletRow(
                                  context,
                                  Icons.tips_and_updates,
                                  AppColors.secondaryContainer,
                                  s,
                                ),
                              if (doc.missingOrWeakTopics.isEmpty &&
                                  doc.speechImprovements.isEmpty)
                                const Text(
                                  'Walang specific na gaps o suggestions na naibalik.',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Practice this speech',
                  icon: Icons.mic_external_on,
                  onPressed: () =>
                      context.push(AppRoutes.practiceSetup, extra: doc.title),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PipSecondaryButton(
                        label: 'Re-analyze',
                        icon: Icons.refresh,
                        onPressed: () => context.go(AppRoutes.documentUpload),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PipGhostButton(
                        label: 'Export cue cards',
                        icon: Icons.style,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cue cards coming soon (mock)'),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bulletRow(
    BuildContext context,
    IconData icon,
    Color bg,
    String body,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: Icon(icon, size: 15, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                body,
                style: text.bodyMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
