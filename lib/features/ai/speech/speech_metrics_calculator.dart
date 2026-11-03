import '../../../core/models/speech_metrics.dart';

/// Deterministic transcript/timestamp metrics, independent of native inference.
class SpeechMetricsCalculator {
  SpeechMetrics calculate({
    required TranscriptionResult transcription,
    required double durationSeconds,
  }) {
    final text = transcription.text.trim();
    if (!transcription.isSuccess || text.isEmpty) {
      return SpeechMetrics.empty();
    }

    final wordCount = text.split(RegExp(r'\s+')).length;
    // Prefer the actual sample-derived WAV duration over the UI timer.
    final measuredDuration = transcription.durationSeconds;
    final duration = measuredDuration.isFinite && measuredDuration > 0
        ? measuredDuration
        : (durationSeconds.isFinite && durationSeconds > 0
              ? durationSeconds
              : 0.0);
    final wpm = duration > 0 ? wordCount * 60.0 / duration : 0.0;

    // Transcript-only detection cannot establish that words such as "like",
    // "so", or Filipino "ano" were fillers rather than meaningful content.
    // Count only explicit hesitation spellings in supported languages.
    final language = transcription.detectedLanguage
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    final supportsFillers = const {
      'auto',
      'en',
      'fil',
      'tl',
    }.contains(language);
    final fillers = <String, int>{};
    if (supportsFillers) {
      fillers['um'] = RegExp(
        r'\bum+\b',
        caseSensitive: false,
      ).allMatches(text).length;
      fillers['uh'] = RegExp(
        r'\buh+\b',
        caseSensitive: false,
      ).allMatches(text).length;
    }

    // These are estimated gaps between Whisper ASR segments, not acoustic
    // silence measurements. With no timestamps available, report no measured
    // gaps instead of inventing a pause count or duration.
    final ordered =
        transcription.segments
            .where(
              (segment) =>
                  segment.startSeconds.isFinite &&
                  segment.endSeconds.isFinite &&
                  segment.startSeconds >= 0 &&
                  segment.endSeconds >= segment.startSeconds &&
                  (duration <= 0 || segment.endSeconds <= duration + 0.05),
            )
            .toList()
          ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    final pauses = <double>[];
    double? previousEnd;
    for (final segment in ordered) {
      if (previousEnd != null) {
        final gap = segment.startSeconds - previousEnd;
        if (gap >= 0.3) pauses.add(gap);
      }
      if (previousEnd == null || segment.endSeconds > previousEnd) {
        previousEnd = segment.endSeconds;
      }
    }

    return SpeechMetrics(
      transcript: text,
      wordCount: wordCount,
      speechDurationSeconds: duration,
      wordsPerMinute: double.parse(wpm.toStringAsFixed(1)),
      fillerOccurrences: fillers,
      totalFillers: fillers.values.fold(0, (sum, count) => sum + count),
      pauseCount: pauses.length,
      avgPauseDurationSeconds: pauses.isEmpty
          ? 0
          : pauses.reduce((a, b) => a + b) / pauses.length,
    );
  }
}
