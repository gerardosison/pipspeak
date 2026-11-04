import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';

/// Product information and credits for the actual PipSpeak implementation.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const projectUrl = 'https://github.com/gerardosison/pipspeak';
  static const _stack = [
    ('Flutter & Material 3', 'Responsive application interface'),
    (
      'Qwen3 0.6B / llama.cpp',
      'Local language-model coaching on supported Android devices',
    ),
    ('Whisper / whisper.cpp', 'Local speech recognition and timing'),
    (
      'Google ML Kit Pose Detection',
      'On-device pose landmarks and movement estimates',
    ),
    (
      'SQLite & Drift',
      'Account-scoped profiles, documents and practice history on this device',
    ),
    (
      'Firebase Authentication & Firestore',
      'Online account access and synchronization of profiles and session summaries',
    ),
  ];

  Future<void> _copyProjectLink(BuildContext context) async {
    try {
      await Clipboard.setData(const ClipboardData(text: projectUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Project link copied.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not copy the link. You can select it below.'),
          ),
        );
      }
    }
  }

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
            tooltip: 'Copy project link',
            icon: const Icon(Icons.link_rounded),
            onPressed: () => _copyProjectLink(context),
          ),
        ],
      ),
      body: PipPageBody(
        maxWidth: 760,
        children: [
          Column(
            children: [
              const PipMascot(
                asset: PipAsset.happy,
                size: 130,
                showBadge: false,
              ),
              const SizedBox(height: 10),
              Text(
                'PipSpeak',
                style: text.headlineLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Your public speaking practice companion',
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0 (Build 1)',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          PipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built for student voices', style: text.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'PipSpeak helps students rehearse speeches, review delivery metrics and receive coaching after a practice session. It can also analyze readable speech documents and support preparation through a local AI coach.',
                ),
              ],
            ),
          ),
          PipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local analysis and platform support',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The native AI models run on supported Android devices when the required model assets are installed. Recordings, transcripts and documents are processed locally. Feedback and pose measurements are estimates intended for practice.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chrome provides account, progress and document text-preview screens. The Android AI runtimes do not run in the browser. Creating an account, signing in for the first time and cloud synchronization require internet access.',
                ),
              ],
            ),
          ),
          PipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Team HawkaBuild', style: text.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'An AppBuildersPH Hackathon project focused on helping students practice public speaking. Project contributors and implementation history are available in the repository.',
                ),
                const SizedBox(height: 12),
                const SelectableText(projectUrl),
              ],
            ),
          ),
          Text('Technologies and models', style: text.titleLarge),
          for (final entry in _stack)
            PipCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.$1, style: text.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    entry.$2,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'PipSpeak',
              applicationVersion: '1.0.0+1',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Software licenses'),
          ),
        ],
      ),
    );
  }
}
