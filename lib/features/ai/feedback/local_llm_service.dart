import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/models/pose_metrics.dart';
import '../../../core/models/speech_metrics.dart';
import 'local_llm_backend.dart';
import 'local_llm_platform_stub.dart'
    if (dart.library.ui) 'local_llm_platform_flutter.dart';

export 'local_llm_backend.dart';

/// Cancels only this request, including a request waiting for the shared model.
class InferenceCancellation {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const InferenceCancelledException();
  }
}

class InferenceCancelledException implements Exception {
  const InferenceCancelledException();
  @override
  String toString() => 'Local AI request cancelled.';
}

class ContextLimitException implements Exception {
  const ContextLimitException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One mobile Qwen runtime shared by chat, document analysis and coaching.
/// Requests serialize; cancelling a queued request cannot stop another feature.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService({
    String modelName = 'Qwen3-0.6B-GGUF (Q4_K_M)',
    bool isEnabled = true,
  }) => _instance;
  LocalLlmService._internal()
    : _backend = createLocalLlmBackend(),
      _resolveModel = resolveDefaultModel;

  factory LocalLlmService.forTesting({
    required LocalLlmBackend backend,
    required Future<String> Function() resolveModel,
    Duration loadTimeout = const Duration(minutes: 2),
    Duration generationTimeout = const Duration(minutes: 2),
    Duration idleTimeout = const Duration(seconds: 45),
    Duration stopTimeout = const Duration(seconds: 5),
  }) => LocalLlmService._testing(
    backend,
    resolveModel,
    loadTimeout,
    generationTimeout,
    idleTimeout,
    stopTimeout,
  );

  LocalLlmService._testing(
    this._backend,
    this._resolveModel,
    this.loadTimeout,
    this.generationTimeout,
    this.idleTimeout,
    this.stopTimeout,
  );

  static const contextSize = 2048;
  static const _safetyTokens = 128;
  static const defaultSystemMessage =
      'You are PipSpeak, an offline public-speaking tutor. Answer the latest '
      'question directly in the user\'s language, including Filipino or Taglish. '
      'Be concise, use only supplied evidence, and never invent measurements. '
      'Do not show reasoning or thinking blocks. /no_think';

  final LocalLlmBackend _backend;
  final Future<String> Function() _resolveModel;
  Duration loadTimeout = const Duration(minutes: 2);
  Duration generationTimeout = const Duration(minutes: 2);
  Duration idleTimeout = const Duration(seconds: 45);
  Duration stopTimeout = const Duration(seconds: 5);
  Future<void>? _initializing;
  Future<void> _tail = Future<void>.value();
  InferenceCancellation? _active;
  bool _isLoaded = false;
  bool _disposed = false;
  bool _quarantined = false;
  String _lastError = '';

  bool get isSupported => supportsLocalLlmRuntime;

  bool get isLoaded => _isLoaded && !_disposed && !_quarantined;
  bool get isLoading => _initializing != null;
  String get lastError => _lastError;

  static String stripThinking(String response) {
    var cleaned = response;
    final block = RegExp(
      r'<think\b[^>]*>[\s\S]*?</think\s*>',
      caseSensitive: false,
    );
    while (block.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(block, '');
    }
    return cleaned
        .replaceFirst(
          RegExp(r'<think\b[^>]*>[\s\S]*$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'</think\s*>', caseSensitive: false), '')
        .replaceFirst(RegExp(r'<\/?think\b[^>]*$', caseSensitive: false), '')
        .trim();
  }

  /// UTF-8 bytes are a conservative upper bound for this byte-level tokenizer.
  /// Reserve output, template framing and safety before admitting history.
  static int userMessageByteBudget({
    int maxTokens = 512,
    String systemMessage = defaultSystemMessage,
  }) =>
      contextSize -
      maxTokens -
      _safetyTokens -
      utf8.encode(systemMessage).length -
      48;

  static List<ChatMessage> budgetMessages({
    required String userMessage,
    List<ChatMessage> history = const [],
    String systemMessage = defaultSystemMessage,
    int maxTokens = 512,
  }) {
    if (maxTokens < 1 || maxTokens > 512) {
      throw ArgumentError('Output must be between 1 and 512 tokens.');
    }
    var remaining =
        userMessageByteBudget(
          maxTokens: maxTokens,
          systemMessage: systemMessage,
        ) -
        utf8.encode(userMessage).length;
    if (userMessage.trim().isEmpty) throw ArgumentError('Enter a message.');
    if (remaining < 0) {
      throw const ContextLimitException(
        'This request is too long for the mobile model. Shorten it or analyze smaller sections.',
      );
    }
    final selected = <ChatMessage>[];
    // Keep only contiguous complete turns, newest first. Never retain an orphan
    // assistant reply or accept a history entry with a privileged system role.
    for (var i = history.length - 1; i >= 1; i -= 2) {
      final assistant = history[i];
      final user = history[i - 1];
      if (user.role != 'user' || assistant.role != 'assistant') break;
      final cost =
          utf8.encode(user.content).length +
          utf8.encode(assistant.content).length +
          32;
      if (cost > remaining) break;
      selected.insertAll(0, [user, assistant]);
      remaining -= cost;
    }
    return [
      ChatMessage(role: 'system', content: systemMessage),
      ...selected,
      ChatMessage(role: 'user', content: userMessage),
    ];
  }

  /// Every concurrent caller awaits the same load. A timeout does not allow a
  /// second native load while the original native operation is still running.
  Future<void> initialize({void Function(String)? onStatus}) async {
    _checkUsable();
    if (isLoaded) return;
    void report(String message) {
      // UI status callbacks must never invalidate an already loaded runtime.
      try {
        onStatus?.call(message);
      } catch (_) {}
    }

    if (_initializing == null) {
      _initializing = Future<void>(() async {
        _lastError = '';
        try {
          report('Checking the local Qwen model…');
          final path = await _resolveModel();
          report('Loading Qwen on CPU…');
          await _backend.load(
            path: path,
            threads: Platform.numberOfProcessors.clamp(1, 4),
            contextSize: contextSize,
            // Reliable baseline across Android drivers. GPU offload must be
            // enabled only after device profiling, not blindly recommended.
            gpuLayers: 0,
          );
          _isLoaded = true;
          report('Offline Qwen is ready.');
        } catch (error) {
          _lastError = error.toString();
          _isLoaded = false;
          rethrow;
        } finally {
          _initializing = null;
        }
      });
    } else {
      report('Waiting for the shared Qwen model to finish loading…');
    }
    await _initializing!.timeout(
      loadTimeout,
      onTimeout: () => throw TimeoutException(
        'Model loading is taking too long. Loading remains in progress; do not start another load.',
        loadTimeout,
      ),
    );
  }

  void _checkUsable() {
    if (_disposed) throw StateError('Local AI runtime has been disposed.');
    if (_quarantined) {
      throw StateError(
        'The native model did not stop safely. Restart the app before using local AI again.',
      );
    }
  }

  String buildCoachingPrompt({
    required SpeechMetrics speech,
    PoseMetrics? pose,
    required String speakingGoal,
  }) {
    final buf = StringBuffer()
      ..writeln('Use only these measured results; do not invent numbers.')
      ..writeln('Goal: $speakingGoal')
      ..writeln('Rate: ${speech.wordsPerMinute.toStringAsFixed(1)} WPM')
      ..writeln('Words: ${speech.wordCount}')
      ..writeln('Detected fillers: ${speech.totalFillers}');
    if (pose != null && pose.isPersonInFrame) {
      buf
        ..writeln(
          'Posture heuristic: ${pose.postureScore.toStringAsFixed(0)}/100',
        )
        ..writeln(
          'Gesture activity: ${pose.handGestureActivityScore.toStringAsFixed(0)}/100',
        );
    }
    buf.writeln('Give 2-3 concise sentences of actionable speaking advice.');
    return buf.toString();
  }

  Stream<String> generateStream({
    required String userMessage,
    List<ChatMessage> conversationHistory = const [],
    String systemMessage = defaultSystemMessage,
    int maxTokens = 512,
    double temperature = 0.7,
    InferenceCancellation? cancellation,
  }) async* {
    _checkUsable();
    final messages = budgetMessages(
      userMessage: userMessage,
      history: conversationHistory,
      systemMessage: systemMessage,
      maxTokens: maxTokens,
    );
    if (!temperature.isFinite || temperature < 0 || temperature > 2) {
      throw ArgumentError('Temperature must be between 0 and 2.');
    }
    final request = cancellation ?? InferenceCancellation();
    request.throwIfCancelled();
    final previous = _tail;
    final release = Completer<void>();
    _tail = previous.then((_) => release.future);
    var started = false;
    StreamSubscription<String>? subscription;
    Timer? deadline;
    StreamController<String>? output;
    var finished = false;
    var mustStop = false;
    try {
      await Future.any<void>([
        previous,
        request.whenCancelled.then(
          (_) => throw const InferenceCancelledException(),
        ),
      ]);
      request.throwIfCancelled();
      _checkUsable();
      await Future.any<void>([
        initialize(),
        request.whenCancelled.then(
          (_) => throw const InferenceCancelledException(),
        ),
      ]);
      request.throwIfCancelled();
      _active = request;
      output = StreamController<String>();
      void fail(Object error) {
        if (finished) return;
        finished = true;
        mustStop = true;
        output!.addError(error);
        unawaited(output.close());
      }

      unawaited(
        request.whenCancelled.then((_) {
          fail(const InferenceCancelledException());
        }),
      );
      deadline = Timer(generationTimeout, () {
        fail(
          TimeoutException(
            'Local AI exceeded its response time limit.',
            generationTimeout,
          ),
        );
      });
      started = true;
      subscription = _backend
          .generate(
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
          )
          .timeout(idleTimeout)
          .listen(
            (token) {
              if (!finished) output!.add(token);
            },
            onError: (Object error, StackTrace stack) => fail(error),
            onDone: () {
              if (finished) return;
              finished = true;
              unawaited(output!.close());
            },
            cancelOnError: true,
          );
      yield* output.stream;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      finished = true;
      deadline?.cancel();
      // Downstream subscription cancellation also stops native work.
      if (started && (mustStop || !output!.isClosed)) {
        try {
          await _backend.stop().timeout(stopTimeout);
        } catch (error) {
          _quarantined = true;
          _lastError = 'Native stop failed: $error';
        }
      }
      await subscription?.cancel();
      if (output != null && !output.isClosed) unawaited(output.close());
      if (identical(_active, request)) _active = null;
      release.complete();
    }
  }

  Future<String> generateResponse(
    String prompt, {
    List<ChatMessage> conversationHistory = const [],
    String systemMessage = defaultSystemMessage,
    int maxTokens = 512,
    InferenceCancellation? cancellation,
  }) async {
    final response = StringBuffer();
    await for (final token in generateStream(
      userMessage: prompt,
      conversationHistory: conversationHistory,
      systemMessage: systemMessage,
      maxTokens: maxTokens,
      cancellation: cancellation,
    )) {
      response.write(token);
    }
    final cleaned = stripThinking(response.toString());
    if (cleaned.isEmpty) {
      throw StateError(
        'The local model returned no usable answer. Try a shorter request.',
      );
    }
    return cleaned;
  }

  Future<void> stopGeneration() async => _active?.cancel();

  Future<void> dispose() async {
    _disposed = true;
    _active?.cancel();
    await _tail;
    // Do not dispose native state while a timed-out load is still running.
    try {
      await _initializing;
    } finally {
      await _backend.dispose();
      _isLoaded = false;
    }
  }
}
