import 'dart:convert';
import 'dart:typed_data';

import 'package:app_builder_hackathon/core/errors/analysis_failure.dart';
import 'package:app_builder_hackathon/features/ai/feedback/local_llm_service.dart';
import 'package:app_builder_hackathon/features/documents/services/local_document_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _DocumentBackend implements LocalLlmBackend {
  int loads = 0;
  int generations = 0;
  List<ChatMessage> messages = const [];
  String response =
      'COVERED TOPICS\n- A clear introduction.\n'
      'MISSING OR WEAK TOPICS\nNone\nSPEECH IMPROVEMENTS\n- Add a closing example.';

  @override
  Future<void> load({
    required String path,
    required int threads,
    required int contextSize,
    required int gpuLayers,
  }) async {
    loads++;
  }

  @override
  Stream<String> generate({
    required List<ChatMessage> messages,
    required int maxTokens,
    required double temperature,
  }) {
    this.messages = messages;
    generations++;
    return Stream.value(response);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late _DocumentBackend backend;
  late LocalDocumentService service;
  setUp(() {
    backend = _DocumentBackend();
    service = LocalDocumentService(
      llm: LocalLlmService.forTesting(
        backend: backend,
        resolveModel: () async => '/verified/fixture.gguf',
      ),
    );
  });
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  test(
    'in-memory TXT keeps metadata and validates local model sections',
    () async {
      const text =
          'This presentation explains how students can practice public speaking with clear examples.';
      final progress = <String>[];
      final result = await service.analyze(
        'speech.txt',
        bytes(text),
        onProgress: progress.add,
      );
      expect(result.extractedText, text);
      expect(result.title, 'speech.txt');
      expect(result.wordCount, 12);
      expect(result.coveredTopics, ['A clear introduction.']);
      expect(result.missingOrWeakTopics, isEmpty);
      expect(result.speechImprovements, ['Add a closing example.']);
      expect(backend.loads, 1);
      expect(backend.generations, 1);
      expect(progress, isNotEmpty);
    },
  );

  test(
    'long Unicode scripts are sampled within context and disclose coverage',
    () async {
      final result = await service.analyze(
        'speech.txt',
        bytes('Mahalaga ang pagsasanay 語言. ' * 1000),
      );
      expect(result.keySections.single, contains('sampled'));
      final prompt = backend.messages.last.content;
      expect(
        utf8.encode(prompt).length,
        lessThanOrEqualTo(
          LocalLlmService.userMessageByteBudget(
            maxTokens: 240,
            systemMessage: backend.messages.first.content,
          ),
        ),
      );
      expect(prompt, contains('DOCUMENT PASSAGES'));
    },
  );

  test('cancelled request never initializes or generates', () async {
    final cancellation = InferenceCancellation()..cancel();
    await expectLater(
      service.analyze(
        'speech.txt',
        bytes('Readable speech content for analysis.'),
        cancellation: cancellation,
      ),
      throwsA(isA<InferenceCancelledException>()),
    );
    expect(backend.loads, 0);
    expect(backend.generations, 0);
  });

  test('unreadable script fails before loading a model', () async {
    await expectLater(
      service.analyze('speech.txt', bytes('?????')),
      throwsA(isA<DocumentUnreadableException>()),
    );
    expect(backend.loads, 0);
  });

  test(
    'oversized extracted text and unknown files fail before inference',
    () async {
      await expectLater(
        service.analyze('speech.txt', bytes('a' * 200001)),
        throwsA(isA<AnalysisFailure>()),
      );
      await expectLater(
        service.analyze(
          'speech.exe',
          bytes('Readable speech content for analysis.'),
        ),
        throwsA(isA<AnalysisFailure>()),
      );
      expect(backend.loads, 0);
    },
  );

  test('truncated model response cannot become successful analysis', () async {
    backend.response = 'COVERED TOPICS\n- Introduction only';
    await expectLater(
      service.analyze(
        'speech.txt',
        bytes('Readable speech content for analysis.'),
      ),
      throwsA(isA<AnalysisFailure>()),
    );
  });
}
