import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../core/widgets/pip_misc.dart';

final _transcriptProvider =
    FutureProvider.family<SessionDetail?, (String, String)>((ref, owner) {
      return ref.watch(progressRepositoryProvider).detail(owner.$1, owner.$2);
    });

/// Shows persisted account-owned transcript data; never invents stars or audio.
class TranscriptReviewScreen extends ConsumerWidget {
  const TranscriptReviewScreen({
    super.key,
    this.speechTopic = '',
    this.durationSeconds = 0,
    this.sessionId,
  });
  final String speechTopic;
  final int durationSeconds;
  final String? sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(genuineRecordsProvider);
    final uid = ref.watch(currentUidProvider);
    final id = sessionId ?? (records.isEmpty ? null : records.first.id);
    final detail = uid == null || id == null
        ? const AsyncData<SessionDetail?>(null)
        : ref.watch(_transcriptProvider((uid, id)));
    return Scaffold(
      appBar: pipAppBar(context, title: 'Saved transcript'),
      body: PipPageBody(
        maxWidth: 760,
        children: [
          detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text(
              'The saved transcript could not be opened. Your session summary is still available in Progress.',
            ),
            data: (value) {
              if (value == null || value.transcript.trim().isEmpty) {
                return const Text(
                  'There is no transcript on this device for this session. Detailed analysis remains on the device where it was recorded.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(value.transcript),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy transcript'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: value.transcript),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transcript copied.')),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
