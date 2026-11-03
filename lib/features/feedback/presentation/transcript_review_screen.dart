import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';
import '../../home/presentation/home_screen.dart';
import 'widgets/coaching_tip_card.dart';

class TranscriptReviewScreen extends StatefulWidget {
  const TranscriptReviewScreen({
    super.key,
    this.speechTopic = 'Tell a story in 60 seconds',
    this.durationSeconds = 64,
  });

  final String speechTopic;
  final int durationSeconds;

  @override
  State<TranscriptReviewScreen> createState() => _TranscriptReviewScreenState();
}

class _TranscriptReviewScreenState extends State<TranscriptReviewScreen> {
  bool _isPlayingAudio = false;
  double _audioProgress = 0.35;
  bool _showAiTips = false;
  bool _starsClaimed = false;

  void _claimStarsAndLevelUp() {
    setState(() {
      _starsClaimed = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Stars Badge
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33FFD166),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('⭐', style: TextStyle(fontSize: 38)),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                '+3 Stars Earned!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Added to your current level progression.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.navySoft),
              ),
              const SizedBox(height: 20),

              // Level progress card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Level: Level 4',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Eloquent Speaker',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const LinearProgressIndicator(
                        value: 0.80, // 12 / 15 stars
                        minHeight: 8,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '12 / 15 Stars to reach Level 5 Master Orator',
                      style: TextStyle(fontSize: 11.5, color: AppColors.navySoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Return to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pipAppBar(context, title: 'Transcript & AI Tips'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Step 2: Review Transcript',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review your speech delivery word-by-word',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),

              // Audio playback controls card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlayingAudio
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                      onPressed: () =>
                          setState(() => _isPlayingAudio = !_isPlayingAudio),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Audio Playback',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '0:24 / 0:${widget.durationSeconds.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _audioProgress,
                              activeColor: AppColors.yellow,
                              inactiveColor: Colors.white24,
                              onChanged: (val) =>
                                  setState(() => _audioProgress = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full Speech Transcript Card with highlights
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FULL TRANSCRIPT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navySoft,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sky,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '148 Words',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Transcript Text with color-coded highlights
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.ink,
                          fontFamily: 'Inter',
                        ),
                        children: [
                          const TextSpan(
                            text: 'Good afternoon everyone. Today I want to share why public speaking is ',
                          ),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'a skill for life',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: '. When we speak, '),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.coral,
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                '[um]',
                                style: TextStyle(
                                  color: AppColors.coral,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(
                            text: ' we often think about words, but body posture and tone are equally vital. In my experience, ',
                          ),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'confidence comes from daily practice',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ', not just natural talent. '),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.coral,
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                '[like]',
                                style: TextStyle(
                                  color: AppColors.coral,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(
                            text: ' taking sixty seconds every morning gives your voice the clarity it deserves. Thank you.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Transcript highlight legend
                    const Row(
                      children: [
                        _LegendItem(color: AppColors.mint, label: 'Strong phrase'),
                        SizedBox(width: 16),
                        _LegendItem(color: AppColors.coral, label: 'Filler word'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Step 3: Get AI Improvement Tips based on what local AI knows from last session
              if (!_showAiTips)
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showAiTips = true),
                    icon: const Icon(Icons.psychology_alt_rounded),
                    label: const Text(
                      'Get AI Improvement Tips',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else ...[
                const CoachingTipCard(
                  lastSessionComparison:
                      'Compared to your session on Tuesday: Filler words dropped by 40% and pace improved from 110 to 138 WPM!',
                  tips: [
                    'Use deliberate 1-second silence instead of filler words when transitioning thoughts.',
                    'Keep holding eye contact with the left and right sections of your audience.',
                    'Your concluding sentence was clear and resolute—keep that energetic ending!',
                  ],
                ),
                const SizedBox(height: 24),

                // Step 4: The user gains Stars that is added to the current level
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _claimStarsAndLevelUp,
                    icon: const Text('⭐', style: TextStyle(fontSize: 18)),
                    label: Text(
                      _starsClaimed
                          ? 'Stars Claimed!'
                          : 'Claim +3 Stars & Level Up',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.navySoft),
        ),
      ],
    );
  }
}

