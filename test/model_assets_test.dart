import 'dart:io';
import 'dart:typed_data';

import 'package:app_builder_hackathon/features/ai/model_management/model_file_resolver.dart';
import 'package:app_builder_hackathon/features/ai/model_management/model_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'readiness comes from runtime results, not declared bundled flags',
    () async {
      final loader = ModelLoader(probe: () async => {});
      final readiness = await loader.checkAllModelsReady();
      expect(readiness.values, everyElement(isFalse));
    },
  );

  test('a legacy pose asset is not a ready ML Kit detector', () async {
    final loader = ModelLoader(
      probe: () async => {'whisper': true, 'pose': true, 'llm': true},
    );
    final readiness = await loader.checkAllModelsReady();
    expect(readiness[ModelLoader.whisperModel.id], isTrue);
    expect(readiness[ModelLoader.mediaPipeModel.id], isFalse);
    expect(readiness[ModelLoader.qwenLlmModel.id], isTrue);
  });

  group('GGUF header checks', () {
    late Directory directory;
    late File file;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('pipspeak-model-test-');
      file = File('${directory.path}/model.gguf');
    });
    tearDown(() => directory.delete(recursive: true));

    test('missing and placeholder artifacts fail', () async {
      await expectLater(validateGgufHeader(file), throwsStateError);
      await file.writeAsString('version https://git-lfs.github.com/spec/v1');
      await expectLater(validateGgufHeader(file), throwsFormatException);
    });

    test('a large file with an invalid header fails', () async {
      await file.writeAsBytes(Uint8List(1024 * 1024 + 1));
      await expectLater(validateGgufHeader(file), throwsFormatException);
    });

    test(
      'supported headers pass format check, not artifact authenticity',
      () async {
        final bytes = Uint8List(1024 * 1024 + 1);
        bytes.setAll(0, 'GGUF'.codeUnits);
        final data = ByteData.sublistView(bytes);
        data.setUint32(4, 3, Endian.little);
        data.setUint64(8, 100, Endian.little);
        data.setUint64(16, 20, Endian.little);
        await file.writeAsBytes(bytes);
        await validateGgufHeader(file);
      },
    );
  });
}
