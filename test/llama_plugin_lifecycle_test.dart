import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:llama_flutter_android/src/llama_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const prefix = 'dev.flutter.pigeon.llama_flutter_android.LlamaHostApi.';
  const codec = LlamaHostApi.pigeonChannelCodec;
  final channels = <BasicMessageChannel<Object?>>[];

  void host(String method, Future<Object?> Function(Object?) handler) {
    final channel = BasicMessageChannel<Object?>('$prefix$method', codec);
    messenger.setMockDecodedMessageHandler<Object?>(channel, handler);
    channels.add(channel);
  }

  setUp(() {
    host('stop', (_) async => <Object?>[]);
    host('dispose', (_) async => <Object?>[]);
    host('generateChat', (_) async => <Object?>[]);
  });
  tearDown(() {
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
    channels.clear();
  });

  test(
    'stop waits for terminal native callback before permitting another job',
    () async {
      final controller = LlamaController();
      final output = controller
          .generateChat(
            messages: [ChatMessage(role: 'user', content: 'Hi')],
          )
          .toList();
      var stopped = false;
      final stop = controller.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(
        stopped,
        isFalse,
        reason: 'stop acknowledgement is not native completion',
      );
      expect(controller.isGenerating, isTrue);
      expect(() => controller.generateChat(messages: []), throwsStateError);
      controller.onDone();
      await stop;
      expect(await output, isEmpty);
      expect(stopped, isTrue);
      await controller.dispose();
    },
  );

  test('stop also drains native work when Dart was recreated', () async {
    final nativeStopped = Completer<Object?>();
    var stopCalls = 0;
    host('stop', (_) {
      stopCalls++;
      return nativeStopped.future;
    });
    final controller = LlamaController();
    var finished = false;
    final stop = controller.stop().then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopCalls, 1);
    expect(finished, isFalse);
    nativeStopped.complete(<Object?>[]);
    await stop;
    expect(finished, isTrue);
    await controller.dispose();
  });

  test('host invocation errors close stream instead of hanging', () async {
    host(
      'generateChat',
      (_) async => <Object?>['native-error', 'Rejected', null],
    );
    final controller = LlamaController();
    await expectLater(
      controller.generateChat(messages: []).toList(),
      throwsA(isA<Exception>()),
    );
    expect(controller.isGenerating, isFalse);
    await controller.dispose();
  });

  test('late host error cannot terminate the next generation', () async {
    final oldReply = Completer<Object?>();
    var calls = 0;
    host(
      'generateChat',
      (_) => ++calls == 1 ? oldReply.future : Future.value(<Object?>[]),
    );
    final controller = LlamaController();
    final first = controller.generateChat(messages: []).toList();
    await Future<void>.delayed(Duration.zero);
    controller.onDone();
    await first;
    final second = controller.generateChat(messages: []).toList();
    oldReply.complete(<Object?>['late-error', 'Old failure', null]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isGenerating, isTrue);
    controller.onToken('Current answer');
    controller.onDone();
    expect(await second, ['Current answer']);
    await controller.dispose();
  });
}
