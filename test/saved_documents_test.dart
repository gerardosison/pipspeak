import 'dart:async';
import 'dart:io';

import 'package:app_builder_hackathon/app/app_providers.dart';
import 'package:app_builder_hackathon/app/app_router.dart';
import 'package:app_builder_hackathon/app/theme/app_theme.dart';
import 'package:app_builder_hackathon/core/models/document_result.dart';
import 'package:app_builder_hackathon/data/local/app_database.dart';
import 'package:app_builder_hackathon/data/codecs/analysis_codec.dart';
import 'package:app_builder_hackathon/data/repositories/account_guard.dart';
import 'package:app_builder_hackathon/data/repositories/document_repository.dart';
import 'package:app_builder_hackathon/features/documents/presentation/document_analysis_screen.dart';
import 'package:app_builder_hackathon/features/documents/presentation/document_upload_screen.dart';
import 'package:app_builder_hackathon/features/documents/presentation/saved_documents_section.dart';
import 'package:app_builder_hackathon/features/documents/providers/saved_documents_provider.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _uid = StateProvider<String?>((_) => 'alice');

const document = DocumentResult(
  documentId: 'saved-speech',
  title:
      'A very long saved student presentation about our university project.txt',
  extractedText: 'My speech remains available after restarting PipSpeak.',
  wordCount: 10,
  estimatedMinutes: 0.0714285714,
  aiAnalyzed: false,
);

void main() {
  test(
    'saved scripts reopen after database restart without another account leak',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pipspeak-documents-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/app.sqlite');
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'alice'),
      );
      var db = AppDatabase.forTesting(NativeDatabase(file));
      await DocumentRepository(
        db,
        guard: AccountGuard(auth),
      ).save('alice', document);
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            DocumentRepository(db, guard: AccountGuard(auth)),
          ),
          currentUidProvider.overrideWith((ref) => ref.watch(_uid)),
        ],
      );
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen(savedDocumentsProvider, (_, next) {
        if ((next.valueOrNull?.isNotEmpty ?? false) && !loaded.isCompleted) {
          loaded.complete();
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await loaded.future.timeout(const Duration(seconds: 2));
      expect(
        container.read(savedDocumentsProvider).requireValue.single.title,
        document.title,
      );
      expect(
        container.read(savedDocumentsProvider).requireValue.single.resultJson,
        contains('My speech remains available'),
      );
      container.read(_uid.notifier).state = 'bob';
      expect(
        container.read(savedDocumentsProvider).valueOrNull,
        isNot(contains(isA<LocalDocument>())),
      );
      expect(
        container
                .read(savedDocumentsProvider)
                .valueOrNull
                ?.any((row) => row.userId == 'alice') ??
            false,
        isFalse,
      );
      container.read(_uid.notifier).state = null;
      expect(container.read(savedDocumentsProvider).requireValue, isEmpty);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('text-only script is readable at narrow width in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [lastDocAnalysisProvider.overrideWith((_) => document)],
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark()
                : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const ScriptAnalysisScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Covered topics'), findsNothing);
      expect(find.text('Gaps to fix'), findsNothing);
      expect(find.text('Text only'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(document.extractedText),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(document.extractedText), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('upload screen remains usable at 320px and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedDocumentsProvider.overrideWithValue(const AsyncData([])),
          selectedGoalProvider.overrideWith((_) => 'Debate'),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const DocumentUploadScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Saved scripts on this device'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'saved script list displays durable content and removal actions',
    (tester) async {
      final row = LocalDocument(
        id: 'saved-speech',
        userId: 'alice',
        title: document.title,
        wordCount: 10,
        resultJson: AnalysisCodec.encodeDocument(document),
        createdAt: DateTime(2026, 11, 4),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: SavedDocumentsSection()),
            ),
          ),
          GoRoute(
            path: AppRoutes.scriptAnalysis,
            builder: (_, _) => const ScriptAnalysisScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedDocumentsProvider.overrideWithValue(AsyncData([row])),
            currentUidProvider.overrideWithValue('alice'),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(document.title), findsOneWidget);
      expect(find.text('Open saved script'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Open saved script'));
      await tester.pumpAndSettle();
      expect(find.text(document.extractedText), findsOneWidget);
      expect(find.text('Text only'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
