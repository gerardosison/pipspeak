import 'dart:async';

/// Stable, student-facing explanations. Technical exceptions remain available
/// for diagnostics rather than being rendered verbatim in chat bubbles.
class LocalAiFailure {
  const LocalAiFailure(this.title, this.message);

  final String title;
  final String message;

  factory LocalAiFailure.from(Object error) {
    final detail = error.toString().toLowerCase();
    if (error is UnsupportedError ||
        detail.contains('arm64') ||
        detail.contains('64-bit android') ||
        detail.contains('not supported on this device')) {
      return const LocalAiFailure(
        'Device not supported',
        'The offline AI Coach requires a supported 64-bit ARM Android phone. '
            'Account and saved-progress screens can still be used on other supported platforms.',
      );
    }
    if (detail.contains('no space') || detail.contains('enospc')) {
      return const LocalAiFailure(
        'Not enough device storage',
        'Free some device storage, restart PipSpeak, and try again. '
            'The offline language model needs a private local copy.',
      );
    }
    if (detail.contains('manifest') ||
        detail.contains('model is missing') ||
        detail.contains('model file is missing') ||
        detail.contains('bundled qwen model is missing') ||
        detail.contains('unable to load asset')) {
      return const LocalAiFailure(
        'Offline model not ready',
        'This installation does not contain a complete verified offline model. '
            'Install an updated PipSpeak build that includes its AI models. '
            'Keep your existing app data when updating.',
      );
    }
    if (detail.contains('integrity') ||
        detail.contains('checksum') ||
        detail.contains('gguf') ||
        detail.contains('corrupt')) {
      return const LocalAiFailure(
        'Offline model could not be verified',
        'The model files are incomplete or damaged. Install a verified PipSpeak update '
            'and try again; your practice history is separate from the model files.',
      );
    }
    if (error is TimeoutException) {
      return const LocalAiFailure(
        'Local AI is taking too long',
        'Try a shorter question or script and close other memory-heavy apps. '
            'If the model cannot stop, restart PipSpeak before trying again.',
      );
    }
    if (detail.contains('too long') || detail.contains('context')) {
      return const LocalAiFailure(
        'Request is too long',
        'Shorten the question or analyze a smaller section of the script. '
            'The mobile model has a limited context window.',
      );
    }
    if (detail.contains('did not stop') || detail.contains('restart the app')) {
      return const LocalAiFailure(
        'Restart local AI',
        'The previous AI request did not stop safely. Restart PipSpeak to reset '
            'the local model, then try again.',
      );
    }
    return const LocalAiFailure(
      'Local AI could not finish',
      'Try again with a shorter request. If it keeps failing, restart PipSpeak '
          'and check that this device has enough free memory and the AI models are installed.',
    );
  }
}
