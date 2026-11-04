import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions/permission_service.dart';
import '../core/services/document_service.dart';
import '../core/services/feedback_service.dart';
import '../core/permissions/platform_permission_service.dart';
import '../core/services/pose_analysis_service.dart';
import '../core/services/speech_recognition_service.dart';
import '../features/ai/feedback/local_llm_service.dart';
import '../features/ai/feedback/rule_based_feedback.dart';
import '../features/ai/speech/whisper_service.dart';
import '../features/ai/vision/mediapipe_pose_service.dart';
import '../features/documents/services/local_document_service.dart';

// Re-export feature-scoped providers + shared option lists so screens
// can keep a single app-level import.
export '../core/constants/app_constants.dart';
export 'account_providers.dart';
export '../data/sync/sync_controller.dart';
export '../features/onboarding/providers/onboarding_provider.dart';
export '../features/practice/providers/practice_provider.dart';
export '../features/feedback/providers/feedback_provider.dart';
export '../features/documents/providers/document_provider.dart';
export '../features/progress/providers/progress_provider.dart';
export '../features/profile/providers/profile_provider.dart';

enum PermissionState { notSet, granted, denied }

final permissionStateProvider = StateProvider<PermissionState>(
  (ref) => PermissionState.notSet,
);

// --------------------------------------------------------------- Services
// Production services use real platform/model implementations.
final permissionServiceProvider = Provider<PermissionService>(
  (_) => PlatformPermissionService(),
);
final speechRecognitionProvider = Provider<SpeechRecognitionService>(
  (_) => WhisperSpeechService(),
);
final poseAnalysisProvider = Provider<PoseAnalysisService>(
  (_) => MediaPipePoseServiceImpl(),
);
final feedbackServiceProvider = Provider<FeedbackService>(
  (_) => RuleBasedFeedbackEngine(llmService: LocalLlmService()),
);
final documentServiceProvider = Provider<DocumentService>(
  (_) => LocalDocumentService(),
);

// ------------------------------------------------------------------- Auth
/// Simple onboarding/auth gate for the router redirect.
final authStateProvider = StateProvider<AuthStage>((_) => AuthStage.splash);

enum AuthStage { splash, signedOut, onboarding, personalization, signedIn }
