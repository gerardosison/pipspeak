import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../../../app/theme/app_colors.dart';

class SpeechAnalysisProcessingRequest {
  const SpeechAnalysisProcessingRequest({
    required this.status,
    required this.onCancel,
  });

  final ValueListenable<String> status;
  final VoidCallback onCancel;
}

class SpeechAnalysisProcessingScreen extends StatefulWidget {
  const SpeechAnalysisProcessingScreen({super.key, required this.request});

  final SpeechAnalysisProcessingRequest request;

  @override
  State<SpeechAnalysisProcessingScreen> createState() =>
      _SpeechAnalysisProcessingScreenState();
}

class _SpeechAnalysisProcessingScreenState
    extends State<SpeechAnalysisProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
    lowerBound: 0.94,
    upperBound: 1.04,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.request.onCancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) =>
                          Transform.scale(scale: _pulse.value, child: child),
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blue.withValues(alpha: 0.22),
                          border: Border.all(
                            color: AppColors.sky.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.3),
                              blurRadius: 34,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 50,
                          color: AppColors.sky,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Preparing your speech insights',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                      valueListenable: widget.request.status,
                      builder: (context, status, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          status,
                          key: ValueKey(status),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 9,
                          color: AppColors.sky,
                          backgroundColor: Color(0x553A4B6B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your recording stays on this device while it is analyzed.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: widget.request.onCancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel and discard speech'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
