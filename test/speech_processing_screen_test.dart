import 'package:app_builder_hackathon/features/practice/presentation/speech_analysis_processing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('speech processing renders live status and cancels explicitly', (
    tester,
  ) async {
    final status = ValueNotifier<String>('Loading the local model');
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SpeechAnalysisProcessingScreen(
          request: SpeechAnalysisProcessingRequest(
            status: status,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );
    expect(find.text('Loading the local model'), findsOneWidget);
    status.value = 'Saving your practice insights';
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saving your practice insights'), findsOneWidget);
    await tester.tap(find.text('Cancel and discard speech'));
    expect(cancelled, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    status.dispose();
  });

  testWidgets(
    'system back invokes cancellation instead of resuming live speech',
    (tester) async {
      final status = ValueNotifier<String>('Transcribing');
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SpeechAnalysisProcessingScreen(
            request: SpeechAnalysisProcessingRequest(
              status: status,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(cancelled, 1);
      expect(find.byType(SpeechAnalysisProcessingScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      status.dispose();
    },
  );
}
