import 'dart:async';
import 'dart:io';

import 'package:app_builder_hackathon/core/models/speech_metrics.dart';
import 'package:app_builder_hackathon/features/ai/speech/whisper_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hawkabuild.app/ai');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  SpeechMetrics measure(
    String text, {
    double actualDuration = 10,
    double timerDuration = 10,
    String language = 'en',
    List<TranscriptSegment> segments = const [],
  }) => WhisperSpeechService().calculateMetrics(
    transcription: TranscriptionResult(
      text: text,
      durationSeconds: actualDuration,
      detectedLanguage: language,
      segments: segments,
    ),
    durationSeconds: timerDuration,
  );

  test('uses sample-derived audio duration rather than the UI timer', () {
    final metrics = measure('one two three four five', timerDuration: 20);
    expect(metrics.wordsPerMinute, 30);
    expect(metrics.speechDurationSeconds, 10);
  });

  test('missing duration never invents a 30-second recording', () {
    final metrics = measure('one two', actualDuration: 0, timerDuration: 0);
    expect(metrics.wordCount, 2);
    expect(metrics.wordsPerMinute, 0);
    expect(metrics.speechDurationSeconds, 0);
    expect(measure('one two', actualDuration: double.nan).wordsPerMinute, 12);
  });

  test('empty transcripts and absent timings never fabricate pauses', () {
    expect(measure('  \n ').wordCount, 0);
    final metrics = measure('There is no timestamp evidence.');
    expect(metrics.pauseCount, 0);
    expect(metrics.avgPauseDurationSeconds, 0);
  });

  test('counts actual ASR segment gaps rather than segment boundaries', () {
    final metrics = measure(
      'one two three four',
      segments: const [
        TranscriptSegment(id: 0, startSeconds: 0, endSeconds: 1, text: 'one'),
        TranscriptSegment(id: 1, startSeconds: 1, endSeconds: 2, text: 'two'),
        TranscriptSegment(id: 2, startSeconds: 3, endSeconds: 4, text: 'three'),
        TranscriptSegment(id: 3, startSeconds: 6, endSeconds: 7, text: 'four'),
      ],
    );
    expect(metrics.pauseCount, 2);
    expect(metrics.avgPauseDurationSeconds, 1.5);
  });

  test('invalid or overlapping segment timings do not invent pause gaps', () {
    final metrics = measure(
      'one two three',
      segments: const [
        TranscriptSegment(id: 0, startSeconds: 0, endSeconds: 5, text: 'one'),
        TranscriptSegment(id: 1, startSeconds: 1, endSeconds: 2, text: 'two'),
        TranscriptSegment(id: 2, startSeconds: 4, endSeconds: 6, text: 'three'),
        TranscriptSegment(id: 3, startSeconds: 9, endSeconds: 8, text: 'bad'),
        TranscriptSegment(id: 4, startSeconds: 20, endSeconds: 21, text: 'bad'),
      ],
    );
    expect(metrics.pauseCount, 0);
  });

  test(
    'counts hesitation sounds without labeling meaningful like/so as fillers',
    () {
      final metrics = measure('Um, I like science so much. Umm... uh, uhh.');
      expect(metrics.fillerOccurrences, {'um': 2, 'uh': 2});
      expect(metrics.totalFillers, 4);
      expect(measure('Um livro', language: 'pt-BR').totalFillers, 0);
    },
  );

  test('concurrent initializers both await a single native load', () async {
    var loads = 0;
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'initializeWhisper');
      loads++;
      return ready.future;
    });
    final service = WhisperSpeechService();
    final first = service.initializeModel();
    final second = service.initializeModel();
    var secondFinished = false;
    unawaited(second.then((_) => secondFinished = true));
    await Future<void>.delayed(Duration.zero);
    expect(loads, 1);
    expect(secondFinished, isFalse);
    ready.complete(true);
    await Future.wait([first, second]);
    expect(await service.isModelLoaded(), isTrue);
  });

  test('failed initialization can be retried', () async {
    var loads = 0;
    messenger.setMockMethodCallHandler(channel, (_) async => ++loads > 1);
    final service = WhisperSpeechService();
    await expectLater(service.initializeModel(), throwsStateError);
    await service.initializeModel();
    expect(loads, 2);
    expect(await service.isModelLoaded(), isTrue);
  });

  test(
    'native timestamp response is preserved and malformed segments ignored',
    () async {
      final directory = await Directory.systemTemp.createTemp('pipspeak-asr-');
      addTearDown(() => directory.delete(recursive: true));
      final audio = await File('${directory.path}/sample.wav')
          .writeAsBytes([0]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initializeWhisper') return true;
        return {
          'text': '  hello world  ',
          'durationSeconds': 4.0,
          'language': 'en',
          'segments': [
            {'startSeconds': 0.0, 'endSeconds': 1.0, 'text': 'hello'},
            {'startSeconds': 2.0, 'endSeconds': 3.0, 'text': 'world'},
            {'startSeconds': -1, 'endSeconds': 0, 'text': 'bad'},
            {'startSeconds': 'bad', 'endSeconds': 2, 'text': 'bad'},
          ],
        };
      });
      final service = WhisperSpeechService();
      final result = await service.transcribe(audio.path);
      expect(result.text, 'hello world');
      expect(result.segments, hasLength(2));
      final metrics = service.calculateMetrics(
        transcription: result,
        durationSeconds: 4,
      );
      expect(metrics.pauseCount, 1);
      expect(metrics.avgPauseDurationSeconds, 1);
    },
  );
}
