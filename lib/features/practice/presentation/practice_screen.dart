import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/models/feedback_report.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/pose_metrics.dart';
import '../../../core/models/speech_metrics.dart';
import '../../../features/ai/feedback/local_llm_service.dart';
import '../../../features/ai/feedback/rule_based_feedback.dart';
import '../services/audio_recorder_service.dart';
import '../services/camera_platform_support.dart';
import '../services/pose_camera_session.dart';
import 'widgets/audience_character.dart';
import 'widgets/practice_timer.dart';
import 'widgets/recording_controls.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    super.key,
    this.speechTopic = 'Tell a story in 60 seconds',
    this.isCameraInitiallyOn = true,
    this.isMicInitiallyOn = true,
    this.cameraName,
    this.microphoneDeviceId,
  });

  final String speechTopic;
  final bool isCameraInitiallyOn;
  final bool isMicInitiallyOn;
  final String? cameraName;
  final String? microphoneDeviceId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  // Step 2: Countdown state (10s to 0)
  bool _isCountingDown = true;
  int _countdownSeconds = 10;
  Timer? _countdownTimer;

  // Step 3: Live speech timer
  int _elapsedSpeechSeconds = 0;
  Timer? _speechTimer;

  final AudioRecorderService _audio = AudioRecorderService();
  final PoseCameraSession _poseSession = PoseCameraSession();
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  Future<void>? _cameraPreparation;
  late bool _isCameraOn;
  late bool _isMicOn;
  bool _isAnalyzing = false;
  InferenceCancellation? _analysisRequest;

  /// Generated once so retries never create a duplicate saved session.
  final String _sessionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _isCameraOn = widget.isCameraInitiallyOn;
    _isMicOn = widget.isMicInitiallyOn;
    if (_isCameraOn) _cameraPreparation = _prepareCamera();
    _startCountdown();
  }

  Future<void> _prepareCamera() async {
    try {
      if (!cameraPluginSupportedOnCurrentPlatform) {
        throw UnsupportedError(cameraPluginUnavailableMessage);
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No connected camera is available.');
      }
      final selectedCamera = _firstOrNull(
        cameras.where((item) => item.name == widget.cameraName),
      );
      if (widget.cameraName != null && selectedCamera == null) {
        throw StateError('The selected camera is no longer connected.');
      }
      final camera =
          selectedCamera ??
          _firstOrNull(
            cameras.where(
              (item) => item.lensDirection == CameraLensDirection.front,
            ),
          ) ??
          cameras.first;
      final controller = PoseCameraSession.createCameraController(camera);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraDescription = camera;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _isCameraOn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is MissingPluginException || error is UnsupportedError
                  ? cameraPluginUnavailableMessage
                  : 'Camera unavailable: $error',
            ),
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        _startLiveSpeech();
      }
    });
  }

  void _startLiveSpeech() {
    setState(() {
      _isCountingDown = false;
      _countdownSeconds = 0;
    });
    unawaited(_startRealCapture());

    // Start speech timer
    _speechTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSpeechSeconds++);
    });
  }

  Future<void> _startRealCapture() async {
    try {
      if (_isMicOn) {
        final devices = await _audio.listInputDevices();
        final matching = devices.where(
          (device) => device.id == widget.microphoneDeviceId,
        );
        final selectedDevice = matching.isEmpty ? null : matching.first;
        if (widget.microphoneDeviceId != null && selectedDevice == null) {
          throw StateError('The selected microphone is no longer connected.');
        }
        _audio.selectInputDevice(selectedDevice);
        await _audio.startRecording(device: selectedDevice);
      }
      if (_isCameraOn) {
        await (_cameraPreparation ??= _prepareCamera());
      }
      final controller = _cameraController;
      final camera = _cameraDescription;
      if (_isCameraOn && controller != null && camera != null) {
        await _poseSession.start(controller, camera);
      }
      if (mounted) {
        setState(() {
          _isMicOn = _audio.isRecording;
          _isCameraOn = _cameraController?.value.isInitialized == true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isMicOn = _audio.isRecording;
          _isCameraOn = _cameraController?.value.isInitialized == true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start the recording/camera: $error'),
          ),
        );
      }
    }
  }

  void _skipCountdown() {
    _countdownTimer?.cancel();
    _startLiveSpeech();
  }

  // Step 4: The user can end the speech by clicking the X button at the bottom middle
  Future<void> _endSpeech() async {
    if (_isAnalyzing) return;
    final request = InferenceCancellation();
    _analysisRequest = request;
    final accountId = ref.read(currentUidProvider);
    final practicePurpose = ref.read(selectedGoalProvider);
    final language = ref.read(selectedLanguageProvider);
    _speechTimer?.cancel();
    setState(() => _isAnalyzing = true);
    try {
      final recordedSeconds = _audio.secondsElapsed;
      final seconds = recordedSeconds > 0
          ? recordedSeconds
          : _elapsedSpeechSeconds;
      final audioPath = await _audio.stopAndGetPath();
      PoseMetrics? poseMetrics;
      if (_poseSession.isRunning) {
        poseMetrics = await _poseSession.stop(_sessionId);
      }
      if (!mounted || request.isCancelled) return;
      final hasAudio = _isMicOn && audioPath != null && recordedSeconds > 0;
      final hasPose = poseMetrics != null && poseMetrics.totalFrames > 0;
      if (!hasAudio && !hasPose) {
        throw StateError(
          'No usable audio or camera frames were captured. Enable a microphone or camera and try again.',
        );
      }

      final speechService = ref.read(speechRecognitionProvider);
      var metrics = SpeechMetrics.empty();
      if (hasAudio) {
        final transcription = await speechService.transcribe(audioPath);
        if (!mounted || request.isCancelled) return;
        if (!transcription.isSuccess) {
          throw StateError(
            transcription.errorMessage ?? 'Could not transcribe the recording.',
          );
        }
        metrics = speechService.calculateMetrics(
          transcription: transcription,
          durationSeconds: seconds.toDouble(),
        );
      }
      ref.read(lastSpeechMetricsProvider.notifier).state = metrics;
      ref.read(lastPoseMetricsProvider.notifier).state = poseMetrics;

      final llm = LocalLlmService();
      try {
        if (!llm.isLoaded) {
          await Future.any<void>([llm.initialize(), request.whenCancelled]);
        }
      } on Object {
        // The local LLM is optional; rule-based feedback is still evidence-based.
      }
      if (!mounted || request.isCancelled) return;
      final feedback = ref.read(feedbackServiceProvider);
      final document = ref.read(lastDocAnalysisProvider);
      final report = feedback is RuleBasedFeedbackEngine
          ? await feedback.generate(
              speech: metrics,
              pose: poseMetrics,
              document: document,
              speakingGoal: widget.speechTopic,
              cancellation: request,
            )
          : await feedback.generate(
              speech: metrics,
              pose: poseMetrics,
              document: document,
              speakingGoal: widget.speechTopic,
            );
      if (!mounted) return;
      final uid = ref.read(currentUidProvider);
      if (uid == null || uid != accountId) {
        throw StateError(
          'Account changed. This session was not saved to another account.',
        );
      }
      // Save locally first; cloud sync happens afterwards.
      final saved = await ref
          .read(progressRepositoryProvider)
          .saveCompletedPractice(
            userId: uid,
            sessionId: _sessionId,
            practicePurpose: practicePurpose,
            language: language,
            topic: widget.speechTopic,
            durationSeconds: seconds,
            report: report,
            speech: hasAudio ? metrics : null,
            pose: hasPose ? poseMetrics : null,
            audioPath: audioPath,
          );
      if (!mounted || ref.read(currentUidProvider) != accountId) return;
      ref.read(lastReportProvider.notifier).state = FeedbackReport(
        overallScore: report.overallScore,
        summary: report.summary,
        strengths: report.strengths,
        improvements: report.improvements,
        evidenceList: report.evidenceList,
        limitations: report.limitations,
        generatedAt: report.generatedAt,
        localLlmPrompt: report.localLlmPrompt,
        llmResponse: report.llmResponse,
        starsEarned: saved.starsEarned,
      );
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
      final session = practiceSessionFromRecord(saved);
      if (mounted) {
        context.pushReplacement(AppRoutes.rehearsalAnalysis, extra: session);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analysis did not finish: $error')),
        );
      }
    } finally {
      if (identical(_analysisRequest, request)) _analysisRequest = null;
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _speechTimer?.cancel();
    _analysisRequest?.cancel();
    unawaited(_audio.dispose());
    unawaited(_poseSession.dispose());
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      return _buildCountdownView();
    }
    return _buildLiveSpeechView();
  }

  // ---------------------------------------------------------------------------
  // STEP 2: PREPARE THE USER & COUNTDOWN WITH TIMER FROM 10 SECS TO 0
  // ---------------------------------------------------------------------------
  Widget _buildCountdownView() {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: _skipCountdown,
                  icon: const Icon(
                    Icons.fast_forward_rounded,
                    color: AppColors.sky,
                  ),
                  label: const Text(
                    'Skip to speech',
                    style: TextStyle(color: AppColors.sky),
                  ),
                ),
              ),
              const Spacer(),

              // Calming preparation instruction
              const Center(
                child: Text(
                  'PREPARE YOUR SPEECH',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Take a deep breath and stand tall.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 40),

              // Animated Countdown Timer Display (10 secs to 0)
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.blue, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x334F7CFF),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$_countdownSeconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Your mock audience is seated and listening...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: FULL-SCREEN BACKGROUND OF MOCK CARTOON AUDIENCE,
  // TIMER THAT KEEPS TRACK OF SPEECH TIME, INDICATOR OF VOICE LOUDNESS.
  // STEP 4: END SPEECH BY CLICKING THE X BUTTON AT BOTTOM MIDDLE.
  // ---------------------------------------------------------------------------
  Widget _buildLiveSpeechView() {
    if (_isAnalyzing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Transcribing offline audio and preparing your Qwen feedback…',
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Step 3: Full-screen background of mock cartoon audience
          const MockCartoonAudienceBackground(),

          // Top Overlay: Timer, Topic & PIP Self View
          Positioned(
            top: 44,
            left: 18,
            right: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Timer that keeps track of the speech time
                PracticeTimerWidget(elapsedSeconds: _elapsedSpeechSeconds),

                // Self Camera PIP thumbnail
                Container(
                  width: 76,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white38, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isCameraOn &&
                          _cameraController?.value.isInitialized == true)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CameraPreview(_cameraController!),
                        )
                      else
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white54,
                          size: 38,
                        ),
                      Positioned(
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Speech Prompt Capsule Banner
          Positioned(
            top: 110,
            left: 20,
            right: 106,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Prompt: ${widget.speechTopic}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Step 3: Indicator of voice loudness
          Positioned(
            left: 20,
            right: 20,
            bottom: 120,
            child: _buildVoiceLoudnessIndicator(),
          ),

          // Step 4: The user can end the speech by clicking the X button at the bottom middle
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: RecordingControlsWidget(onEndSpeech: _endSpeech),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a recording state without displaying simulated loudness readings.
  Widget _buildVoiceLoudnessIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isMicOn && _audio.isRecording
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            color: _isMicOn && _audio.isRecording
                ? AppColors.yellow
                : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isMicOn && _audio.isRecording
                  ? 'Audio is recording locally for offline Whisper transcription.'
                  : 'Microphone is off. Speech delivery metrics are paused.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;
