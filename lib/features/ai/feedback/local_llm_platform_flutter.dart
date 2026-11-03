import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../model_management/model_file_resolver.dart';
import 'local_llm_backend.dart';
import 'local_llm_platform_stub.dart' as unsupported;

bool get supportsLocalLlmRuntime =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

LocalLlmBackend createLocalLlmBackend() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? _PluginBackend()
    : unsupported.createLocalLlmBackend();
Future<String> resolveDefaultModel() => resolveQwenModel();

class _PluginBackend implements LocalLlmBackend {
  final llama.LlamaController _controller = llama.LlamaController();
  @override
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  }) async {
    // Flutter hot restart can retain the Android model while recreating Dart.
    // Drain old native work before reusing the verified, packaged model context.
    if (await _controller.isModelLoaded()) {
      await _controller.stop();
      await _controller.clearContext();
      return;
    }
    await _controller.loadModel(
      modelPath: path,
      threads: threads,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
    );
    if (!await _controller.isModelLoaded()) {
      throw StateError(
        'The native Qwen runtime did not load the verified model.',
      );
    }
  }

  @override
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  }) => _controller.generateChat(
    messages: [
      for (final m in messages)
        llama.ChatMessage(role: m.role, content: m.content),
    ],
    template: 'chatml',
    maxTokens: maxTokens,
    temperature: temperature,
    topP: 0.9,
    repeatPenalty: 1.1,
  );
  @override
  Future<void> stop() => _controller.stop();
  @override
  Future<void> dispose() => _controller.dispose();
}
