import 'dart:convert';

import 'package:app_builder_hackathon/features/ai/presentation/local_coach_screen.dart';
import 'package:app_builder_hackathon/features/documents/services/local_document_service.dart';
import 'package:app_builder_hackathon/core/widgets/profile_photo.dart';
import 'package:app_builder_hackathon/core/widgets/primary_button.dart';
import 'package:app_builder_hackathon/app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Chrome coach explains native support without invoking path_provider',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const LocalCoachScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining('not available in this browser'),
        findsOneWidget,
      );
      expect(find.textContaining('MissingPluginException'), findsNothing);
      expect(tester.takeException(), isNull);
      final send = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Ask the AI Coach',
        ),
      );
      expect(send.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test('browser-compatible text extraction needs no AI or filesystem plugins', () async {
    const source =
        'A clear introduction explains the goal of our student presentation and its supporting examples.';
    final result = await LocalDocumentService().analyze(
      'speech.txt',
      Uint8List.fromList(utf8.encode(source)),
      textOnlyPreview: true,
    );
    expect(result.extractedText, source);
    expect(result.aiAnalyzed, isFalse);
    expect(result.coveredTopics, isEmpty);
    expect(result.keySections.single, contains('no AI analysis'));
  });
  test('small local profile photos use portable memory images', () {
    final photo = encodeProfilePhoto([1, 2, 3]);
    expect(profilePhoto(photo), isA<MemoryImage>());
    expect(profilePhoto('data:image/jpeg;base64,%%%'), isNull);
  });
  test('custom button colors receive readable foregrounds', () {
    for (final background in [
      Colors.yellow,
      Colors.lightBlue,
      Colors.black,
      Colors.grey,
    ]) {
      final foreground = PrimaryButton.foregroundFor(background);
      final a = foreground.computeLuminance(),
          b = background.computeLuminance();
      final ratio = ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
