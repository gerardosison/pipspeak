/// Runtime-neutral chat message. Native plugin objects stay at the boundary.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
}

/// Injectable native boundary; lifecycle tests do not need model weights.
abstract interface class LocalLlmBackend {
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  });
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  });
  Future<void> stop();
  Future<void> dispose();
}
