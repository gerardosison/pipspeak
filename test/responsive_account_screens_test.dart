import 'package:app_builder_hackathon/app/app_providers.dart';
import 'package:app_builder_hackathon/app/theme/app_theme.dart';
import 'package:app_builder_hackathon/core/models/models.dart';
import 'package:app_builder_hackathon/features/auth/presentation/login_screen.dart';
import 'package:app_builder_hackathon/features/auth/presentation/register_screen.dart';
import 'package:app_builder_hackathon/features/home/presentation/home_screen.dart';
import 'package:app_builder_hackathon/features/onboarding/presentation/welcome_screen.dart';
import 'package:app_builder_hackathon/features/onboarding/presentation/tour_screen.dart';
import 'package:app_builder_hackathon/features/onboarding/presentation/personalization_screen.dart';
import 'package:app_builder_hackathon/features/profile/presentation/profile_screen.dart';
import 'package:app_builder_hackathon/features/settings/presentation/about_screen.dart';
import 'package:app_builder_hackathon/features/settings/presentation/privacy_screen.dart';
import 'package:app_builder_hackathon/features/profile/presentation/edit_profile_screen.dart';
import 'package:app_builder_hackathon/features/progress/presentation/progress_screen.dart';
import 'package:app_builder_hackathon/features/progress/services/level_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const user = UserProfile(
  uid: 'real-user',
  name: 'Alexandria Santos Dela Cruz',
  nickname: 'Alexandria',
  email: 'alexandria.santos@example.edu',
  level: 2,
  stars: 7,
  streakDays: 12,
  totalSessions: 30,
  school: 'A very long university name',
);

void main() {
  final screens = <String, Widget>{
    'home': const HomeLandingScreen(),
    'profile': const ProfileScreen(),
    'progress': const ProgressScreen(),
    'edit profile': const EditProfileScreen(),
    'welcome': const WelcomeScreen(nickname: 'Alexandria Santos Dela Cruz'),
    'tour': const TourScreen(),
    'language preference': const PersonalizationScreen(),
    'goal preference': const PersonalizationScreen(initialStep: 1),
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'about': const AboutScreen(),
    'privacy': const PrivacyScreen(),
  };
  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(320, 568),
      const Size(640, 280),
      const Size(768, 1024),
      const Size(1280, 800),
    ]) {
      for (final screen in screens.entries) {
        testWidgets(
          '${screen.key} fits ${size.width}x${size.height} at large text in $brightness',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  currentUserProvider.overrideWithValue(user),
                  sessionHistoryProvider.overrideWithValue(const []),
                  genuineRecordsProvider.overrideWithValue(const []),
                  levelStatusProvider.overrideWithValue(
                    LevelService.fromTotalStars(17),
                  ),
                  syncLabelProvider.overrideWithValue(
                    const SyncLabel(
                      'Waiting to sync (1234 saved on this device)',
                    ),
                  ),
                ],
                child: MaterialApp(
                  theme: brightness == Brightness.light
                      ? AppTheme.light()
                      : AppTheme.dark(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(1.8)),
                    child: child!,
                  ),
                  home: screen.value,
                ),
              ),
            );
            await tester.pump(const Duration(seconds: 2));
            expect(tester.takeException(), isNull);
            expect(find.textContaining('Maya'), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('unselected goals remain readable in ${theme.brightness}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWithValue(user)],
          child: MaterialApp(
            theme: theme,
            home: const PersonalizationScreen(initialStep: 1),
          ),
        ),
      );
      final label = find.text('Others');
      final text = tester.widget<Text>(label);
      final card = tester.widget<Card>(
        find.ancestor(of: label, matching: find.byType(Card)),
      );
      final foreground = text.style!.color!.computeLuminance();
      final background = card.color!.computeLuminance();
      final ratio =
          ((foreground > background ? foreground : background) + 0.05) /
          ((foreground < background ? foreground : background) + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  }
  testWidgets('preference save failure keeps the form available for retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue(user.uid),
          currentUserProvider.overrideWithValue(user),
          profileRepositoryProvider.overrideWith(
            (ref) => throw StateError('Storage unavailable'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PersonalizationScreen(initialStep: 1),
        ),
      ),
    );
    await tester.tap(find.text('Build my personalized plan'));
    await tester.pump();
    expect(
      find.text(
        'Could not save your preferences on this device. Please try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Saving preferences…'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });
}
