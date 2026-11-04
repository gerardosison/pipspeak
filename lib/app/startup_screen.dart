import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';

// A retained account with a cached profile opens without a server read. A new
// device must first recover its cloud profile so defaults cannot replace it.
final _recoverProfileProvider = FutureProvider.autoDispose.family<void, String>(
  (ref, uid) async {
    final user = ref.read(authUserProvider).valueOrNull;
    if (user == null || user.uid != uid) return;
    await ref.read(authServiceProvider).ensureLocalProfile(user);
  },
);

/// Waits for retained Firebase identity and SQLite, recovering only if missing.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    final profile = ref.watch(localProfileProvider);
    final user = auth.valueOrNull;
    final missing =
        user != null && profile.hasValue && profile.valueOrNull == null;
    final recovery = missing
        ? ref.watch(_recoverProfileProvider(user.uid))
        : const AsyncData<void>(null);
    final failed = auth.hasError || profile.hasError || recovery.hasError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!failed) const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  failed
                      ? (recovery.hasError
                            ? 'Your profile could not be loaded on this device.'
                            : 'Your saved account could not be opened.')
                      : (missing
                            ? 'Loading your saved profile…'
                            : 'Opening PipSpeak…'),
                  textAlign: TextAlign.center,
                ),
                if (failed) ...[
                  const SizedBox(height: 12),
                  Text(
                    recovery.hasError
                        ? 'Connect to the internet and retry. Your saved cloud profile has not been replaced.'
                        : 'Your local data has not been deleted. Retry, or restart the app.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      if (missing) {
                        ref.invalidate(_recoverProfileProvider(user.uid));
                      } else {
                        ref.invalidate(authUserProvider);
                        if (profile.hasError) {
                          ref.invalidate(appDatabaseProvider);
                        }
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
