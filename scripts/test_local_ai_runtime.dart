// Standalone regression runner intentionally works before pub dependency resolution.
// ignore_for_file: avoid_relative_lib_imports
// Execute without pub or model weights:
// dart --disable-dart-dev scripts/test_local_ai_runtime.dart
// Exercises the actual production coordinator with an injected native boundary.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/features/ai/feedback/local_llm_service.dart';

typedef Check = FutureOr<void> Function();

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> throws<T extends Object>(Future<dynamic> operation) async {
  try {
    await operation;
  } catch (error) {
    require(error is T, 'Expected $T, received ${error.runtimeType}: $error');
    return;
  }
  throw StateError('Expected $T but operation succeeded.');
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

class Backend implements LocalLlmBackend {
  int loads = 0;
  int stops = 0;
  int generations = 0;
  int disposals = 0;
  Future<void> Function()? onLoad;
  Stream<String> Function()? onGenerate;
  Future<void> Function()? onStop;

  @override
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  }) async {
    loads++;
    require(contextSize == 2048, 'Unexpected context size');
    require(gpuLayers == 0, 'Unprofiled GPU offload enabled');
    require(threads >= 1 && threads <= 4, 'Invalid CPU thread count');
    await onLoad?.call();
  }

  @override
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  }) {
    generations++;
    require(messages.first.role == 'system', 'Missing system prompt');
    require(messages.last.role == 'user', 'Missing latest question');
    return onGenerate?.call() ?? Stream.value('Useful answer.');
  }

  @override
  Future<void> stop() async {
    stops++;
    await onStop?.call();
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

LocalLlmService service(Backend backend) => LocalLlmService.forTesting(
  backend: backend,
  resolveModel: () async => '/verified/model.gguf',
);

Future<void> main() async {
  final checks = <(String, Check)>[
    (
      'concurrent initialization awaits one native load',
      () async {
        final loading = Completer<void>();
        final backend = Backend()..onLoad = () => loading.future;
        final model = service(backend);
        var secondFinished = false;
        final first = model.initialize();
        final second = model.initialize().then((_) => secondFinished = true);
        await tick();
        require(backend.loads == 1, 'Concurrent loads started');
        require(
          !secondFinished && model.isLoading,
          'Initialization returned early',
        );
        loading.complete();
        await Future.wait([first, second]);
        require(
          model.isLoaded && !model.isLoading,
          'Model not ready after load',
        );
        await model.dispose();
      },
    ),
    (
      'failed initialization resets and retries',
      () async {
        final backend = Backend()
          ..onLoad = () async => throw StateError('bad model');
        final model = service(backend);
        await throws<StateError>(model.initialize());
        require(
          !model.isLoading && !model.isLoaded,
          'Failed load remains ready',
        );
        backend.onLoad = null;
        await model.initialize();
        require(backend.loads == 2 && model.isLoaded, 'Retry failed');
        await model.dispose();
      },
    ),
    (
      'load timeout cannot start overlapping native load',
      () async {
        final loading = Completer<void>();
        final backend = Backend()..onLoad = () => loading.future;
        final model = service(backend)
          ..loadTimeout = const Duration(milliseconds: 15);
        await throws<TimeoutException>(model.initialize());
        require(model.isLoading, 'Timed-out native load lost ownership');
        await throws<TimeoutException>(model.initialize());
        require(backend.loads == 1, 'Timeout started duplicate load');
        loading.complete();
        await tick();
        await model.initialize();
        require(model.isLoaded, 'Completed original load not reused');
        await model.dispose();
      },
    ),
    (
      'chat and document requests serialize',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend()..onGenerate = () => tokens.stream;
        final model = service(backend);
        final first = model.generateResponse('Chat');
        await tick();
        await tick();
        final second = model.generateResponse('Document');
        await tick();
        require(backend.generations == 1, 'Inference requests overlapped');
        backend.onGenerate = () => Stream.value('Document answer');
        tokens.add('Chat answer');
        await tokens.close();
        require(await first == 'Chat answer', 'Chat response mixed');
        require(await second == 'Document answer', 'Document response mixed');
        require(backend.generations == 2, 'Second request not started');
        await model.dispose();
      },
    ),
    (
      'cancel queued request preserves active inference',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend()..onGenerate = () => tokens.stream;
        final model = service(backend);
        final first = model.generateResponse('First');
        await tick();
        await tick();
        final cancellation = InferenceCancellation();
        final cancelled = throws<InferenceCancelledException>(
          model.generateResponse('Queued', cancellation: cancellation),
        );
        cancellation.cancel();
        await cancelled;
        require(
          backend.stops == 0,
          'Queued cancellation stopped another request',
        );
        require(
          backend.generations == 1,
          'Cancelled request reached native inference',
        );
        tokens.add('Done');
        await tokens.close();
        require(await first == 'Done', 'Active response lost');
        await model.dispose();
      },
    ),
    (
      'cancel active request waits for native stop before next job',
      () async {
        final tokens = StreamController<String>();
        final stopped = Completer<void>();
        final backend = Backend();
        backend.onGenerate = () => tokens.stream;
        backend.onStop = () => stopped.future;
        final model = service(backend);
        final cancellation = InferenceCancellation();
        final first = throws<InferenceCancelledException>(
          model.generateResponse('First', cancellation: cancellation),
        );
        await tick();
        await tick();
        final second = model.generateResponse('Next');
        cancellation.cancel();
        await tick();
        require(backend.stops == 1, 'Active request not stopped');
        require(backend.generations == 1, 'Queue started before native stop');
        backend.onGenerate = () => Stream.value('Next answer');
        stopped.complete();
        await first;
        require(await second == 'Next answer', 'Queue failed to resume');
        await tokens.close();
        await model.dispose();
      },
    ),
    (
      'idle timeout stops stalled native generation',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend()..onGenerate = () => tokens.stream;
        final model = service(backend)
          ..idleTimeout = const Duration(milliseconds: 15);
        await throws<TimeoutException>(model.generateResponse('Stalled'));
        require(backend.stops == 1, 'Stalled generation not stopped');
        await tokens.close();
        await model.dispose();
      },
    ),
    (
      'failed native stop quarantines runtime',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend();
        backend.onGenerate = () => tokens.stream;
        backend.onStop = () async => throw StateError('native failure');
        final model = service(backend)
          ..idleTimeout = const Duration(milliseconds: 15);
        await throws<TimeoutException>(model.generateResponse('Stalled'));
        await throws<StateError>(model.generateResponse('Must not start'));
        require(backend.generations == 1, 'Quarantined runtime reused');
        await tokens.close();
        await model.dispose();
      },
    ),
    (
      'empty or reasoning-only responses fail clearly',
      () async {
        final backend = Backend()
          ..onGenerate = () => Stream.value('<think>hidden</think>');
        final model = service(backend);
        await throws<StateError>(model.generateResponse('Hello'));
        await model.dispose();
      },
    ),
    (
      'history budget keeps newest complete turns',
      () {
        final history = <ChatMessage>[
          for (var i = 0; i < 100; i++) ...[
            ChatMessage(role: 'user', content: 'Question $i'),
            ChatMessage(role: 'assistant', content: 'Answer $i'),
          ],
        ];
        final messages = LocalLlmService.budgetMessages(
          userMessage: 'Latest',
          history: history,
        );
        require(messages.first.role == 'system', 'System prompt lost');
        require(messages.last.content == 'Latest', 'Current request lost');
        require(
          messages[messages.length - 2].content == 'Answer 99',
          'Newest complete turn lost',
        );
        require(messages.length < history.length, 'History never bounded');
        final bytes = messages.fold<int>(
          0,
          (sum, m) => sum + utf8.encode(m.content).length + 16,
        );
        require(bytes + 512 + 128 <= 2048, 'Reserved context budget exceeded');
      },
    ),
    (
      'oversized Unicode request rejected before load',
      () async {
        final backend = Backend();
        final model = service(backend);
        await throws<ContextLimitException>(model.generateResponse('語' * 2000));
        require(
          backend.loads == 0 && backend.generations == 0,
          'Oversized prompt reached model',
        );
        await model.dispose();
      },
    ),
    (
      'thinking cleanup hides complete and partial blocks',
      () {
        require(
          LocalLlmService.stripThinking('Answer<think>private') == 'Answer',
          'Incomplete reasoning leaked',
        );
        require(
          LocalLlmService.stripThinking('<think>private</think>Answer') ==
              'Answer',
          'Reasoning leaked',
        );
      },
    ),
    (
      'total deadline limits continuously streaming generation',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend()..onGenerate = () => tokens.stream;
        final model = service(backend)
          ..idleTimeout = const Duration(milliseconds: 100)
          ..generationTimeout = const Duration(milliseconds: 25);
        final producing = Timer.periodic(
          const Duration(milliseconds: 2),
          (_) => tokens.add('word '),
        );
        try {
          await throws<TimeoutException>(model.generateResponse('Too long'));
          require(
            backend.stops == 1,
            'Total deadline did not stop native work',
          );
        } finally {
          producing.cancel();
          await tokens.close();
          await model.dispose();
        }
      },
    ),
    (
      'native stop timeout quarantines runtime',
      () async {
        final tokens = StreamController<String>();
        final neverStops = Completer<void>();
        final backend = Backend();
        backend.onGenerate = () => tokens.stream;
        backend.onStop = () => neverStops.future;
        final model = service(backend)
          ..idleTimeout = const Duration(milliseconds: 15)
          ..stopTimeout = const Duration(milliseconds: 15);
        await throws<TimeoutException>(model.generateResponse('Stalled'));
        await throws<StateError>(model.generateResponse('Must not overlap'));
        require(backend.generations == 1, 'Stop timeout permitted another job');
        neverStops.complete();
        await tokens.close();
        await model.dispose();
      },
    ),
    (
      'dispose cleans native backend even when pending load fails',
      () async {
        final loading = Completer<void>();
        final backend = Backend()..onLoad = () => loading.future;
        final model = service(backend);
        final initial = throws<StateError>(model.initialize());
        await tick();
        final disposed = throws<StateError>(model.dispose());
        await tick();
        require(backend.disposals == 0, 'Disposed while load still active');
        loading.completeError(StateError('native load failure'));
        await initial;
        await disposed;
        require(
          backend.disposals == 1 && !model.isLoaded,
          'Failed load prevented cleanup',
        );
      },
    ),
    (
      'cancellation during shared load does not trigger another load',
      () async {
        final loading = Completer<void>();
        final backend = Backend()..onLoad = () => loading.future;
        final model = service(backend);
        final cancellation = InferenceCancellation();
        final first = throws<InferenceCancelledException>(
          model.generateResponse('First', cancellation: cancellation),
        );
        await tick();
        await tick();
        cancellation.cancel();
        await first;
        final second = model.generateResponse('Second');
        await tick();
        require(
          backend.loads == 1 && backend.generations == 0,
          'Cancelled load duplicated native work',
        );
        loading.complete();
        require(
          await second == 'Useful answer.',
          'Shared loading not reusable after cancellation',
        );
        await model.dispose();
      },
    ),
    (
      'downstream stream cancellation stops native generation',
      () async {
        final tokens = StreamController<String>();
        final backend = Backend()..onGenerate = () => tokens.stream;
        final model = service(backend);
        final subscription = model
            .generateStream(userMessage: 'Streaming')
            .listen((_) {});
        await tick();
        await tick();
        tokens.add('A');
        await tick();
        await subscription.cancel();
        require(
          backend.stops == 1,
          'Subscription cancellation left native work running',
        );
        await tokens.close();
        await model.dispose();
      },
    ),
    (
      'throwing UI status callbacks do not invalidate shared loading',
      () async {
        final loading = Completer<void>();
        final backend = Backend()..onLoad = () => loading.future;
        final model = service(backend);
        final first = model.initialize(
          onStatus: (_) => throw StateError('widget gone'),
        );
        final second = model.initialize(
          onStatus: (_) => throw StateError('another widget gone'),
        );
        await tick();
        loading.complete();
        await Future.wait([first, second]);
        require(
          model.isLoaded && backend.loads == 1,
          'Status callback broke native readiness',
        );
        await model.dispose();
      },
    ),
    (
      'malformed privileged history is excluded',
      () {
        final messages = LocalLlmService.budgetMessages(
          userMessage: 'Latest',
          history: [
            const ChatMessage(role: 'system', content: 'Untrusted override'),
            const ChatMessage(role: 'assistant', content: 'Reply'),
          ],
        );
        require(messages.length == 2, 'Privileged history admitted');
      },
    ),
  ];
  var passed = 0;
  for (final (name, check) in checks) {
    try {
      await Future<void>.sync(check).timeout(const Duration(seconds: 10));
      passed++;
      stdout.writeln('PASS $name');
    } catch (error, stack) {
      stderr.writeln('FAIL $name: $error\n$stack');
      exitCode = 1;
    }
  }
  stdout.writeln(
    '$passed/${checks.length} production coordinator checks passed.',
  );
}
