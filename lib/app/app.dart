import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'app_providers.dart';
import 'theme/app_theme.dart';

class PipSpeakApp extends ConsumerWidget {
  const PipSpeakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(currentUidProvider, (previous, next) {
      if (previous == next) return;
      ref.invalidate(lastReportProvider);
      ref.invalidate(lastSpeechMetricsProvider);
      ref.invalidate(lastPoseMetricsProvider);
      ref.invalidate(lastDocAnalysisProvider);
    });
    // Keep the sync controller alive for the whole app session.
    ref.listen(syncControllerProvider, (_, _) {});
    return MaterialApp.router(
      title: 'PipSpeak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Shown when Firebase is not configured for the current platform.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'PipSpeak could not start Firebase on this platform.\n\n'
                'Run `flutterfire configure` for this platform and rebuild.\n\n'
                '$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
