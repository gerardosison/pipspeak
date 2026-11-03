import 'dart:async';
import 'dart:convert';

import 'package:app_builder_hackathon/features/ai/feedback/local_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Backend implements LocalLlmBackend {
  int loads = 0;
  int stops = 0;
  int generations = 0;
  int disposals = 0;
  Future<void> Function()? loadAction;
  Stream<String> Function()? generateAction;
  Future<void> Function()? stopAction;
  @override
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  }) async {
    loads++;
    expect(contextSize, 2048);
    expect(gpuLayers, 0);
    expect(threads, inInclusiveRange(1, 4));
    await loadAction?.call();
  }

  @override
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  }) {
    generations++;
    return generateAction?.call() ?? Stream.value('Useful answer.');
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopAction?.call();
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

LocalLlmService _service(_Backend backend) => LocalLlmService.forTesting(
  backend: backend,
  resolveModel: () async => '/verified/model.gguf',
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('concurrent initializers wait for one native load', () async {
    final loading = Completer<void>();
    final backend = _Backend()..loadAction = () => loading.future;
    final model = _service(backend);
    var secondFinished = false;
    final first = model.initialize();
    final second = model.initialize().then((_) => secondFinished = true);
    await tick();
    expect(backend.loads, 1);
    expect(secondFinished, isFalse);
    expect(model.isLoading, isTrue);
    loading.complete();
    await Future.wait([first, second]);
    expect(model.isLoaded, isTrue);
    expect(model.isLoading, isFalse);
  });

  test('failed loading resets and can retry', () async {
    final backend = _Backend()
      ..loadAction = () async => throw StateError('bad model');
    final model = _service(backend);
    await expectLater(model.initialize(), throwsStateError);
    expect(model.isLoading, isFalse);
    backend.loadAction = null;
    await model.initialize();
    expect(backend.loads, 2);
    expect(model.isLoaded, isTrue);
  });

  test('load timeout cannot start another concurrent native load', () async {
    final loading = Completer<void>();
    final backend = _Backend()..loadAction = () => loading.future;
    final model = _service(backend)
      ..loadTimeout = const Duration(milliseconds: 10);
    await expectLater(model.initialize(), throwsA(isA<TimeoutException>()));
    expect(model.isLoading, isTrue);
    await expectLater(model.initialize(), throwsA(isA<TimeoutException>()));
    expect(backend.loads, 1);
    loading.complete();
    await tick();
    await model.initialize();
    expect(model.isLoaded, isTrue);
  });

  test('chat and document inference cannot overlap', () async {
    final firstStream = StreamController<String>();
    final backend = _Backend()..generateAction = () => firstStream.stream;
    final model = _service(backend);
    final first = model.generateResponse('First');
    await tick();
    await tick();
    final second = model.generateResponse('Second');
    await tick();
    expect(backend.generations, 1);
    backend.generateAction = () => Stream.value('Second answer');
    firstStream.add('First answer');
    await firstStream.close();
    expect(await first, 'First answer');
    expect(await second, 'Second answer');
    expect(backend.generations, 2);
  });

  test('cancel queued request without stopping active request', () async {
    final stream = StreamController<String>();
    final backend = _Backend()..generateAction = () => stream.stream;
    final model = _service(backend);
    final first = model.generateResponse('First');
    await tick();
    await tick();
    final cancellation = InferenceCancellation();
    final second = model.generateResponse('Second', cancellation: cancellation);
    final assertion = expectLater(
      second,
      throwsA(isA<InferenceCancelledException>()),
    );
    cancellation.cancel();
    await assertion;
    expect(backend.stops, 0);
    expect(backend.generations, 1);
    stream.add('Done');
    await stream.close();
    expect(await first, 'Done');
  });

  test(
    'cancel active request stops native work before queue proceeds',
    () async {
      final stream = StreamController<String>();
      final stopped = Completer<void>();
      final backend = _Backend();
      backend.generateAction = () => stream.stream;
      backend.stopAction = () => stopped.future;
      final model = _service(backend);
      final cancellation = InferenceCancellation();
      final first = model.generateResponse('First', cancellation: cancellation);
      final assertion = expectLater(
        first,
        throwsA(isA<InferenceCancelledException>()),
      );
      await tick();
      await tick();
      final second = model.generateResponse('Second');
      cancellation.cancel();
      await tick();
      expect(backend.stops, 1);
      expect(backend.generations, 1);
      backend.generateAction = () => Stream.value('Next');
      stopped.complete();
      await assertion;
      expect(await second, 'Next');
      await stream.close();
    },
  );

  test('stalled generation times out and stops native work', () async {
    final stream = StreamController<String>();
    final backend = _Backend()..generateAction = () => stream.stream;
    final model = _service(backend)
      ..idleTimeout = const Duration(milliseconds: 10);
    await expectLater(
      model.generateResponse('Hello'),
      throwsA(isA<TimeoutException>()),
    );
    expect(backend.stops, 1);
    await stream.close();
  });

  test(
    'failed native stop quarantines runtime instead of overlapping jobs',
    () async {
      final stream = StreamController<String>();
      final backend = _Backend();
      backend.generateAction = () => stream.stream;
      backend.stopAction = () async => throw StateError('native failure');
      final model = _service(backend)
        ..idleTimeout = const Duration(milliseconds: 10);
      await expectLater(
        model.generateResponse('Hello'),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(model.generateResponse('Next'), throwsStateError);
      expect(backend.generations, 1);
      await stream.close();
    },
  );

  test('empty or reasoning-only answer fails clearly', () async {
    final backend = _Backend()
      ..generateAction = () => Stream.value('<think>hidden</think>');
    await expectLater(
      _service(backend).generateResponse('Hello'),
      throwsStateError,
    );
  });

  test('context budget keeps newest complete turns and current message', () {
    final history = <ChatMessage>[];
    for (var i = 0; i < 100; i++) {
      history.add(ChatMessage(role: 'user', content: 'Question $i'));
      history.add(ChatMessage(role: 'assistant', content: 'Answer $i'));
    }
    final messages = LocalLlmService.budgetMessages(
      userMessage: 'Latest',
      history: history,
    );
    expect(messages.first.role, 'system');
    expect(messages.last.content, 'Latest');
    expect(messages[messages.length - 2].content, 'Answer 99');
    expect(messages.length, lessThan(history.length));
    final upperBound = messages.fold<int>(
      0,
      (n, m) => n + utf8.encode(m.content).length + 16,
    );
    expect(upperBound + 512 + 128, lessThanOrEqualTo(2048));
  });

  test(
    'oversized multilingual request fails before invoking native model',
    () async {
      final backend = _Backend();
      await expectLater(
        _service(backend).generateResponse('語' * 2000),
        throwsA(isA<ContextLimitException>()),
      );
      expect(backend.loads, 0);
      expect(backend.generations, 0);
    },
  );

  test('thinking cleanup removes incomplete streaming blocks', () {
    expect(LocalLlmService.stripThinking('Answer<think>private'), 'Answer');
    expect(
      LocalLlmService.stripThinking('<think>private</think>Answer'),
      'Answer',
    );
  });
}
