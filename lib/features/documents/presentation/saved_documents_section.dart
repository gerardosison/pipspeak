import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_router.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../data/codecs/analysis_codec.dart';
import '../../../data/local/app_database.dart';
import '../providers/saved_documents_provider.dart';

/// Saved extracted text and feedback remain usable after closing the app.
class SavedDocumentsSection extends ConsumerWidget {
  const SavedDocumentsSection({super.key});

  void _open(BuildContext context, WidgetRef ref, LocalDocument document) {
    if (ref.read(currentUidProvider) != document.userId) return;
    try {
      final result = AnalysisCodec.decodeDocument(document.resultJson);
      ref.read(lastDocAnalysisProvider.notifier).state = result;
      context.push(AppRoutes.scriptAnalysis);
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This saved script could not be opened. Re-analyze the original document.',
          ),
        ),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    LocalDocument document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved script?'),
        content: Text(
          'Remove “${document.title}” and its analysis from this device? Your original file is unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(currentUidProvider) != document.userId) {
      return;
    }
    try {
      await ref
          .read(documentRepositoryProvider)
          .remove(document.userId, document.id);
      if (!context.mounted || ref.read(currentUidProvider) != document.userId) {
        return;
      }
      if (ref.read(lastDocAnalysisProvider)?.documentId == document.id) {
        ref.read(lastDocAnalysisProvider.notifier).state = null;
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The saved script could not be removed. Please retry.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(savedDocumentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Saved scripts on this device',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        documents.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text(
            'Saved scripts could not be read. Your database has not been deleted; restart the app and retry.',
          ),
          data: (rows) => rows.isEmpty
              ? const Text(
                  'Scripts you extract or analyze will appear here. They stay on this device and are not uploaded.',
                )
              : Column(
                  children: [
                    for (final document in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PipCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                document.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${document.wordCount} words · saved locally',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    label: const Text('Open saved script'),
                                    onPressed: () =>
                                        _open(context, ref, document),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remove'),
                                    onPressed: () =>
                                        _remove(context, ref, document),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
