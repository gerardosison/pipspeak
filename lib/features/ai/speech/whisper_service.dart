import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/models/speech_metrics.dart';
import '../../../core/services/speech_recognition_service.dart';
import 'speech_metrics_calculator.dart';

/// Offline Android transcription through the bundled whisper.cpp JNI runtime.
class WhisperSpeechService implements SpeechRecognitionService {
  static const MethodChannel _channel = MethodChannel('com.hawkabuild.app/ai');
  bool _isLoaded = false;
  Future<void>? _initialization;

  @override
  Future<bool> isModelLoaded() async {
    return _isLoaded;
  }

  Future<void> initializeModel() {
    if (_isLoaded) return Future.value();
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    try {
      _isLoaded =
          await _channel.invokeMethod<bool>('initializeWhisper') ?? false;
    } on PlatformException catch (error) {
      _isLoaded = false;
      throw StateError(
        error.message ?? 'Could not initialize the local Whisper model.',
      );
    } on MissingPluginException {
      _isLoaded = false;
      throw StateError(
        'The Android AI method channel is not registered. Confirm the app launches com.hawkabuild.app.MainActivity.',
      );
    }
    if (!_isLoaded) {
      throw StateError('Could not initialize the local Whisper model.');
    }
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String language = 'auto',
  }) async {
    if (audioPath.isEmpty) {
      return TranscriptionResult.failure('Audio file path is empty.');
    }
    if (!await File(audioPath).exists()) {
      return TranscriptionResult.failure(
        'Audio file does not exist: $audioPath',
      );
    }

    try {
      if (!_isLoaded) await initializeModel();
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'transcribe',
        {'audioPath': audioPath, 'language': language},
      );
      final text = (response?['text'] as String? ?? '').trim();
      final duration = (response?['durationSeconds'] as num?)?.toDouble() ?? 0;
      if (text.isEmpty) {
        return TranscriptionResult.failure('Whisper returned no speech text.');
      }
      return TranscriptionResult(
        text: text,
        durationSeconds: duration,
        detectedLanguage: response?['language'] as String? ?? language,
        segments: _parseSegments(response?['segments'], duration),
      );
    } on PlatformException catch (error) {
      return TranscriptionResult.failure(
        error.message ?? 'Offline Whisper transcription failed.',
      );
    } on MissingPluginException {
      return TranscriptionResult.failure(
        'The Android AI method channel is not registered. Confirm the app launches com.hawkabuild.app.MainActivity.',
      );
    } on StateError catch (error) {
      return TranscriptionResult.failure(error.message.toString());
    }
  }

  @override
  SpeechMetrics calculateMetrics({
    required TranscriptionResult transcription,
    required double durationSeconds,
  }) {
    return SpeechMetricsCalculator().calculate(
      transcription: transcription,
      durationSeconds: durationSeconds,
    );
  }

  static List<TranscriptSegment> _parseSegments(Object? raw, double duration) {
    if (raw is! List) return const [];
    final segments = <TranscriptSegment>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final start = entry['startSeconds'];
      final end = entry['endSeconds'];
      final text = entry['text'];
      if (start is! num ||
          end is! num ||
          text is! String ||
          !start.isFinite ||
          !end.isFinite ||
          start < 0 ||
          end < start ||
          (duration > 0 && end > duration + 0.05)) {
        continue;
      }
      segments.add(
        TranscriptSegment(
          id: segments.length,
          startSeconds: start.toDouble(),
          endSeconds: end.toDouble(),
          text: text,
        ),
      );
    }
    return List.unmodifiable(segments);
  }
}
