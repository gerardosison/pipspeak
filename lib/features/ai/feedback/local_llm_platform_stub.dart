import 'local_llm_backend.dart';

const bool supportsLocalLlmRuntime = false;

LocalLlmBackend createLocalLlmBackend() => _UnsupportedBackend();
Future<String> resolveDefaultModel() async => throw UnsupportedError(
  'Local Qwen inference requires a supported 64-bit Android device.',
);

class _UnsupportedBackend implements LocalLlmBackend {
  Never _unsupported() => throw UnsupportedError(
    'Local Qwen inference requires a supported 64-bit Android device.',
  );
  @override
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  }) async => _unsupported();
  @override
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  }) => Stream.error(
    UnsupportedError('Local Qwen is unavailable on this platform.'),
  );
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
