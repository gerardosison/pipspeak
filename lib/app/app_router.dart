import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/models.dart';
import 'account_providers.dart';
import 'session_routing.dart';
import 'startup_screen.dart';
import '../core/widgets/workflow_recovery.dart';
import '../features/ai/presentation/local_coach_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/documents/presentation/document_analysis_screen.dart';
import '../features/documents/presentation/document_processing_screen.dart';
import '../features/documents/presentation/document_upload_screen.dart';
import '../features/feedback/presentation/feedback_screen.dart';
import '../features/feedback/presentation/rehearsal_analysis_screen.dart';
import '../features/feedback/presentation/stars_reward_screen.dart';
import '../features/feedback/presentation/transcript_review_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/personalization_screen.dart';
import '../features/onboarding/presentation/tour_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/practice/presentation/processing_screen.dart';
import '../features/practice/presentation/speech_analysis_processing_screen.dart';
import '../features/practice/presentation/setup_screen.dart';
import '../features/practice/presentation/widgets/permission_denied_view.dart';
import '../features/profile/presentation/change_password_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/progress/presentation/session_history_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/privacy_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

abstract final class AppRoutes {
  static const startup = '/startup';
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const tour = '/tour';
  static const personalize = '/personalize';
  static const home = '/home';
  static const aiCoach = '/coach';
  static const practice = '/practice';
  static const progress = '/progress';
  static const profile = '/profile';
  static const practiceSetup = '/practice/setup';
  static const practiceLive = '/practice/live';
  static const practiceDenied = '/practice/denied';
  static const processing = '/practice/processing';
  static const practiceProcessing = '/practice/analysis-processing';
  static const sessionReport = '/feedback/report';
  static const transcript = '/feedback/transcript';
  static const starsReward = '/reward/stars';
  static const keepGoing = '/reward/keep-going';
  static const rehearsalAnalysis = '/analysis';
  static const documentUpload = '/documents';
  static const documentProcessing = '/documents/processing';
  static const scriptAnalysis = '/documents/analysis';
  static const history = '/history';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';
  static const settings = '/settings';
  static const privacy = '/settings/privacy';
  static const about = '/about';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.onDispose(authRefresh.dispose);
  ref.listen(authUserProvider, (_, _) => authRefresh.value++);
  ref.listen(localProfileProvider, (_, _) => authRefresh.value++);
  return GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: authRefresh,
    redirect: (_, state) {
      final auth = ref.read(authUserProvider);
      final profile = ref.read(localProfileProvider);
      return sessionRedirect(
        location: state.matchedLocation,
        authLoading: auth.isLoading && !auth.hasValue,
        authFailed: auth.hasError,
        signedIn: auth.valueOrNull != null,
        profileLoading: profile.isLoading,
        profileFailed: profile.hasError,
        profileMissing: profile.hasValue && profile.valueOrNull == null,
        onboardingComplete: profile.valueOrNull?.onboardingComplete ?? false,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => WelcomeScreen(
          nickname: ref.read(currentUserProvider)?.nickname ?? '',
        ),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: AppRoutes.tour, builder: (_, _) => const TourScreen()),
      GoRoute(
        path: AppRoutes.personalize,
        builder: (_, state) => PersonalizationScreen(
          initialStep: state.extra is int ? state.extra! as int : 0,
        ),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            HomeScreen(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const HomeLandingScreen(),
          ),
          GoRoute(
            path: AppRoutes.aiCoach,
            builder: (_, _) => const LocalCoachScreen(),
          ),
          GoRoute(
            path: AppRoutes.practice,
            redirect: (_, _) => AppRoutes.practiceSetup,
          ),
          GoRoute(
            path: AppRoutes.practiceSetup,
            builder: (_, state) {
              final topic = state.extra;
              return SetupScreen(
                speechTopic: topic is String
                    ? topic
                    : 'Tell a story in 60 seconds',
                showBack: topic is String,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.practiceLive,
            builder: (_, _) => const PracticeScreen(),
          ),
          GoRoute(
            path: AppRoutes.practiceProcessing,
            builder: (_, state) =>
                state.extra is SpeechAnalysisProcessingRequest
                ? SpeechAnalysisProcessingScreen(
                    request: state.extra! as SpeechAnalysisProcessingRequest,
                  )
                : const WorkflowRecovery(returnPath: AppRoutes.practiceSetup),
          ),
          GoRoute(
            path: AppRoutes.practiceDenied,
            builder: (_, _) => const PermissionDeniedView(),
          ),
          GoRoute(
            path: AppRoutes.processing,
            builder: (_, _) => const ProcessingScreen(),
          ),
          GoRoute(
            path: AppRoutes.sessionReport,
            builder: (_, _) => const FeedbackScreen(),
          ),
          GoRoute(
            path: AppRoutes.transcript,
            builder: (_, state) => TranscriptReviewScreen(
              sessionId: state.extra is String ? state.extra! as String : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.starsReward,
            builder: (_, _) => const StarsRewardScreen(),
          ),
          GoRoute(
            path: AppRoutes.keepGoing,
            builder: (_, _) => const KeepGoingScreen(),
          ),
          GoRoute(
            path: AppRoutes.rehearsalAnalysis,
            builder: (_, state) => RehearsalAnalysisScreen(
              session: state.extra is PracticeSession
                  ? state.extra! as PracticeSession
                  : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.documentUpload,
            builder: (_, _) => const DocumentUploadScreen(),
          ),
          GoRoute(
            path: AppRoutes.documentProcessing,
            builder: (_, state) => state.extra is DocumentAnalysisRequest
                ? DocumentProcessingScreen(
                    request: state.extra! as DocumentAnalysisRequest,
                  )
                : const WorkflowRecovery(returnPath: AppRoutes.documentUpload),
          ),
          GoRoute(
            path: AppRoutes.scriptAnalysis,
            builder: (_, _) => const ScriptAnalysisScreen(),
          ),
          GoRoute(
            path: AppRoutes.progress,
            builder: (_, _) => const ProgressScreen(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, _) => const SessionHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            builder: (_, _) => const EditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.changePassword,
            builder: (_, _) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.privacy,
            builder: (_, _) => const PrivacyScreen(),
          ),
          GoRoute(
            path: AppRoutes.about,
            builder: (_, _) => const AboutScreen(),
          ),
        ],
      ),
    ],
  );
});
