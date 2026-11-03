import 'package:flutter/services.dart';

class ModelAssetInfo {
  final String id;
  final String name;
  final String fileName;
  final String format; // 'GGML', 'TASK', 'GGUF'
  final String sizeMb;
  final bool isBundled;
  final String license;

  const ModelAssetInfo({
    required this.id,
    required this.name,
    required this.fileName,
    required this.format,
    required this.sizeMb,
    required this.isBundled,
    required this.license,
  });
}

class ModelLoader {
  ModelLoader({Future<Map<String, bool>> Function()? probe})
    : _probe = probe ?? _probeNative;

  final Future<Map<String, bool>> Function() _probe;

  static const whisperModel = ModelAssetInfo(
    id: 'asr_whisper_base',
    name: 'OpenAI Whisper Base Multilingual',
    fileName: 'ggml-base-q5_1.bin',
    format: 'GGML',
    sizeMb: '57 MB',
    isBundled: true,
    license: 'MIT',
  );

  static const mediaPipeModel = ModelAssetInfo(
    id: 'vision_pose_lite',
    name: 'Google ML Kit Pose Detection',
    fileName: 'Bundled Android SDK model (no .task file)',
    format: 'SDK',
    sizeMb: 'SDK managed',
    isBundled: true,
    license: 'Google ML Kit Terms of Service',
  );

  static const qwenLlmModel = ModelAssetInfo(
    id: 'llm_qwen3_06b',
    name: 'Qwen3 0.6B GGUF',
    fileName: 'qwen3-0.6b-q4_k_m.gguf',
    format: 'GGUF (Q4_K_M)',
    sizeMb: '380 MB',
    isBundled: true, // Packaged by the verified model preparation step.
    license: 'Apache 2.0',
  );

  Future<Map<String, bool>> checkAllModelsReady() async {
    final status = await _probe();
    return {
      whisperModel.id: status['whisper'] == true,
      // A legacy MediaPipe asset probe is not evidence of a ready ML Kit
      // detector. Native/runtime callers must report the actual mlkit status.
      mediaPipeModel.id: status['mlkitPose'] == true,
      qwenLlmModel.id: status['llm'] == true,
    };
  }

  static Future<Map<String, bool>> _probeNative() async {
    try {
      final result = await const MethodChannel('com.hawkabuild.app/ai')
          .invokeMapMethod<String, dynamic>('checkModelStatus');
      return {
        for (final entry in (result ?? <String, dynamic>{}).entries)
          entry.key: entry.value == true,
      };
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }
}
