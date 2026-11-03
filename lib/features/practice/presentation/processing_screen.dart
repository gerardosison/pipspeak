import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../feedback/presentation/feedback_screen.dart';

/// Processing Screen for Step 5: Loads and processes speech behind the scenes
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    this.speechTopic = 'Tell a story in 60 seconds',
    this.durationSeconds = 64,
  });

  final String speechTopic;
  final int durationSeconds;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int _analysisStep = 0;
  Timer? _timer;

  final List<String> _steps = const [
    'Transcribing audio with local speech model...',
    'Analyzing speaking pace, rhythm & filler words...',
    'Evaluating body alignment and gestures...',
    'Generating personalized AI coaching tips...',
  ];

  @override
  void initState() {
    super.initState();
    _startProcessingSimulation();
  }

  void _startProcessingSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) return;
      if (_analysisStep < _steps.length - 1) {
        setState(() => _analysisStep++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToFeedback() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          speechTopic: widget.speechTopic,
          durationSeconds: widget.durationSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_analysisStep + 1) / _steps.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Processing centerpiece
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.sky,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.navy, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1814213D),
                        offset: Offset(4, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Analyzing Your Speech',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'PipSpeak is processing speech delivery and body language metrics behind the scenes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.line,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Steps Checklist Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(_steps.length, (index) {
                    final isComplete = index <= _analysisStep;
                    final isCurrent = index == _analysisStep;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? Colors.green
                                  : AppColors.paper,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isComplete
                                    ? Colors.green
                                    : AppColors.line,
                              ),
                            ),
                            child: isComplete
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _steps[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isComplete
                                    ? AppColors.primaryText(context)
                                    : AppColors.secondaryText(context)
                                          .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),

              // Proceed to Feedback Section button
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _goToFeedback,
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text(
                    'Go to Feedback Section',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
