import 'package:flutter/material.dart';

import 'rehearsal_analysis_screen.dart';

/// Compatibility entry point for older navigation paths. Feedback always comes
/// from a persisted session; this screen must not manufacture demo measurements.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({
    super.key,
    this.speechTopic = 'Tell a story in 60 seconds',
    this.durationSeconds = 0,
  });

  // Retained so existing callers continue compiling. Actual results are read
  // by RehearsalAnalysisScreen from the account's saved practice history.
  final String speechTopic;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) => const RehearsalAnalysisScreen();
}
