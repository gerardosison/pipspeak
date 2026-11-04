import 'package:flutter/material.dart';

import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_misc.dart';

/// Explains actual data handling; no pretend analytics or retention switches.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: pipAppBar(context, title: 'Privacy & Data'),
    body: PipPageBody(
      maxWidth: 760,
      children: [
        for (final section in const [
          (
            'Local analysis',
            'On supported Android devices, speech, pose and language models process your practice locally. Chrome supports account and progress screens; the native Android models do not run in the browser.',
          ),
          (
            'Saved on this device',
            'Recordings, transcripts, documents, detailed feedback and profile photos remain on the device where they were created. Browser storage can be cleared by browser settings or storage eviction.',
          ),
          (
            'Cloud synchronization',
            'Firebase Authentication manages your account. Your profile and numerical session summaries synchronize to Firestore when connected. Pending changes survive closing the app; other devices see them after upload.',
          ),
          (
            'Retention',
            'There is currently no automatic 30-day recording cleanup. Data remains until you remove it or delete your account. Clearing browser/app storage can permanently remove changes that have not synchronized.',
          ),
          (
            'Account deletion',
            'Account deletion requires a connection and reauthentication. It removes your account’s cloud records and this device’s account-owned recordings, saved profile photo and local database data. Copies on other offline devices cannot be erased remotely while those devices are disconnected.',
          ),
        ])
          PipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.$1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(section.$2),
              ],
            ),
          ),
      ],
    ),
  );
}
