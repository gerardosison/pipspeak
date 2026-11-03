import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';
import 'personalization_screen.dart';

/// Theme-aware colours for the tour. The shared [AppColors] aliases (ink,
/// paper, line, blue, navySoft, sky, mint...) are fixed light-mode values, so
/// using them directly in dark mode produced white panels and unreadable text.
/// Every colour on this screen comes from here instead.
class _Pal {
  const _Pal({
    required this.accent,
    required this.onAccent,
    required this.accentFill,
    required this.onAccentFill,
    required this.card,
    required this.inner,
    required this.border,
    required this.text,
    required this.textSoft,
    required this.tile1,
    required this.tile2,
    required this.hero,
    required this.onHero,
    required this.heroLabel,
    required this.success,
    required this.danger,
    required this.shadow,
  });

  /// Brand accent for icons, links, bars, active progress.
  final Color accent;

  /// Text/icon colour placed ON the accent colour.
  final Color onAccent;

  /// Soft tinted fill (chips, avatar, inactive progress, about box).
  final Color accentFill;
  final Color onAccentFill;

  /// Mockup card background, and the panels nested inside it.
  final Color card;
  final Color inner;
  final Color border;

  final Color text;
  final Color textSoft;

  /// Stat tiles.
  final Color tile1;
  final Color tile2;

  /// Highlight card (today's warm-up).
  final Color hero;
  final Color onHero;
  final Color heroLabel;

  final Color success;
  final Color danger;
  final Color shadow;

  static _Pal of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _Pal(
        accent: AppColors.inversePrimary,
        onAccent: AppColors.navyDeep,
        accentFill: AppColors.darkSurface3,
        onAccentFill: AppColors.darkOnSurface,
        card: AppColors.darkSurface1,
        inner: AppColors.darkSurface2,
        border: Color(0xFF3A4A85),
        text: AppColors.darkOnSurface,
        textSoft: AppColors.darkOnSurfaceVariant,
        tile1: AppColors.darkSurface3,
        tile2: Color(0xFF1E4D3B),
        hero: Color(0xFF2B3C85),
        onHero: Colors.white,
        heroLabel: AppColors.sky,
        success: AppColors.tertiaryFixed,
        danger: Color(0xFFFFB4AB),
        shadow: Color(0x66000000),
      );
    }
    return const _Pal(
      accent: AppColors.blue,
      onAccent: Colors.white,
      accentFill: AppColors.sky,
      onAccentFill: AppColors.navy,
      card: AppColors.paper,
      inner: Colors.white,
      border: AppColors.line,
      text: AppColors.ink,
      textSoft: AppColors.navySoft,
      tile1: AppColors.sky,
      tile2: AppColors.mint,
      hero: AppColors.navy,
      onHero: Colors.white,
      heroLabel: AppColors.sky,
      success: Color(0xFF2E7D32),
      danger: AppColors.coral,
      shadow: Color(0x1414213D),
    );
  }
}

class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  int _page = 0;

  final List<_TourPageData> _pages = const [
    _TourPageData(
      title: 'Home',
      icon: Icons.home_rounded,
      tagline: 'Your daily speaking launchpad',
      function:
          'Start each day with quick warm-ups and track your ongoing practice streak.',
      features: [
        'Daily 60-second impromptu speech warm-ups',
        'Habit streak counter & weekly session totals',
        'Quick-start button to jump into live practice',
      ],
      previewType: _PreviewType.home,
    ),
    _TourPageData(
      title: 'Practice',
      icon: Icons.mic_rounded,
      tagline: 'Interactive speech training studio',
      function:
          'Record your talks, receive live coaching hints, and conquer stage fright.',
      features: [
        'Speech audio & video capture with live visualizer',
        'Instant detection of filler words and pacing errors',
        'Dynamic speaking prompts across multiple formats',
      ],
      previewType: _PreviewType.practice,
    ),
    _TourPageData(
      title: 'Progress',
      icon: Icons.insights_rounded,
      tagline: 'Analytics & growth insights',
      function:
          'Visualize your delivery metrics, confidence trends, and score history over time.',
      features: [
        'Fluency, clarity, and pacing performance scores',
        'Weekly practice frequency charts & consistency logs',
        'Detailed audio transcripts with actionable feedback',
      ],
      previewType: _PreviewType.progress,
    ),
    _TourPageData(
      title: 'Profile',
      icon: Icons.person_rounded,
      tagline: 'Your speaker identity & achievements',
      function:
          'Celebrate your growth, view unlocked speech badges, and manage your level.',
      features: [
        'Speaker level progression (Level 1 Novice to Level 5 Master)',
        'Milestone badges (e.g. 7-day Streak, Clarity Champion)',
        'Custom speaking goals and personalized preferences',
      ],
      previewType: _PreviewType.profile,
    ),
    _TourPageData(
      title: 'Settings',
      icon: Icons.tune_rounded,
      tagline: 'Customization, privacy & app information',
      function:
          'Fine-tune microphone inputs, toggle dark mode, and learn about the PipSpeak mission in the About Section.',
      features: [
        'Dark mode and visual appearance controls',
        'Microphone sensitivity calibration and privacy controls',
        'About Section detailing PipSpeak story, version & mission',
      ],
      previewType: _PreviewType.settings,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      setState(() => _page++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PersonalizationScreen()),
      );
    }
  }

  void _previous() {
    if (_page > 0) {
      setState(() => _page--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _pages[_page];
    final pal = _Pal.of(context);

    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'Preview ${_page + 1} of ${_pages.length}',
        showBack: _page > 0,
        onBack: _previous,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: pal.accent),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PersonalizationScreen()),
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              Row(
                children: List.generate(
                  _pages.length,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 5,
                      margin: EdgeInsets.only(
                        right: index == _pages.length - 1 ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _page ? pal.accent : pal.accentFill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Page Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: pal.accentFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pal.border, width: 1.5),
                    ),
                    child: Icon(
                      currentPage.icon,
                      color: pal.onAccentFill,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPage.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: pal.text,
                              ),
                        ),
                        Text(
                          currentPage.tagline,
                          style: TextStyle(fontSize: 13, color: pal.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Screen Preview + Tooltip Container
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PagePreviewMockup(previewType: currentPage.previewType),
                      const SizedBox(height: 32),
                      _TooltipCallout(data: currentPage),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Navigation Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pal.accent,
                    foregroundColor: pal.onAccent,
                  ),
                  child: Text(
                    _page == _pages.length - 1
                        ? 'Personalize my journey'
                        : 'Next: ${_pages[_page + 1].title}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PreviewType { home, practice, progress, profile, settings }

class _TourPageData {
  const _TourPageData({
    required this.title,
    required this.icon,
    required this.tagline,
    required this.function,
    required this.features,
    required this.previewType,
  });

  final String title;
  final IconData icon;
  final String tagline;
  final String function;
  final List<String> features;
  final _PreviewType previewType;
}

/// Info section highlighting the page function and features.
class _TooltipCallout extends StatelessWidget {
  const _TooltipCallout({required this.data});

  final _TourPageData data;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 24, color: pal.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${data.title} function & features',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  color: pal.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Text(
          'FUNCTION:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: pal.accent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.function,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: pal.text),
        ),
        const SizedBox(height: 12),

        Text(
          'KEY FEATURES:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: pal.accent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        ...data.features.map(
          (feat) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: pal.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feat,
                    style: TextStyle(fontSize: 13, height: 1.35, color: pal.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Visual UI preview card for each page
class _PagePreviewMockup extends StatelessWidget {
  const _PagePreviewMockup({required this.previewType});

  final _PreviewType previewType;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Container(
      height: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: pal.border, width: 2),
        boxShadow: [
          BoxShadow(color: pal.shadow, offset: const Offset(4, 5), blurRadius: 0),
        ],
      ),
      child: switch (previewType) {
        _PreviewType.home => const _HomePreview(),
        _PreviewType.practice => const _PracticePreview(),
        _PreviewType.progress => const _ProgressPreview(),
        _PreviewType.profile => const _ProfilePreview(),
        _PreviewType.settings => const _SettingsPreview(),
      },
    );
  }
}

class _HomePreview extends StatelessWidget {
  const _HomePreview();

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App top bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PipSpeak • Home',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: pal.text,
              ),
            ),
            Tooltip(
              message: 'Quick streak count',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.accentFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔥 7 Days',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pal.onAccentFill,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Warm up card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.hero,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "TODAY'S WARM-UP",
                  style: TextStyle(
                    color: pal.heroLabel,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tell a story in 60 seconds',
                  style: TextStyle(
                    color: pal.onHero,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick exercise for a clearer, firmer vocal tone.',
                  style: TextStyle(
                    color: pal.onHero.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(value: '12', label: 'Sessions', fill: pal.tile1)),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(value: '88%', label: 'Fluency', fill: pal.tile2)),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.fill});

  final String value;
  final String label;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: pal.onAccentFill,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: pal.onAccentFill)),
        ],
      ),
    );
  }
}

class _PracticePreview extends StatelessWidget {
  const _PracticePreview();

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Live Speech Training Studio',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: pal.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pal.inner,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Text(
            'Prompt: Explain your favorite hobby in 2 mins',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pal.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Mic circle
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: pal.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: pal.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.mic_rounded, color: pal.onAccent, size: 28),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq_rounded, color: pal.danger, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Real-time Pacing & Filler Word Detection',
                style: TextStyle(
                  fontSize: 11,
                  color: pal.textSoft,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview();

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Speech Trends & Performance',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: pal.text,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ScoreTile(label: 'Confidence', value: '92/100', fill: pal.tile1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreTile(label: 'Clarity', value: '89%', fill: pal.tile2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Mini graph bars
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pal.inner,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(pal, 'Mon', 40),
                _bar(pal, 'Tue', 65),
                _bar(pal, 'Wed', 85),
                _bar(pal, 'Thu', 70),
                _bar(pal, 'Fri', 90),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(_Pal pal, String day, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 14,
          height: height * 0.4,
          decoration: BoxDecoration(
            color: pal.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: TextStyle(fontSize: 9, color: pal.textSoft)),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value, required this.fill});

  final String label;
  final String value;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: pal.onAccentFill)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: pal.onAccentFill,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview();

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: pal.accentFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 28,
                color: pal.onAccentFill,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex Speaker',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: pal.text,
                  ),
                ),
                Text(
                  'Level 4: Eloquent Speaker',
                  style: TextStyle(fontSize: 11, color: pal.accent),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.inner,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BADGES & ACHIEVEMENTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: pal.textSoft,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('🏅 7-Day Streak',
                      style: TextStyle(fontSize: 11, color: pal.text)),
                  Text('🎙️ 10+ Speeches',
                      style: TextStyle(fontSize: 11, color: pal.text)),
                  Text('⭐ 90% Clarity',
                      style: TextStyle(fontSize: 11, color: pal.text)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview();

  @override
  Widget build(BuildContext context) {
    final pal = _Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Settings & Controls',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: pal.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: pal.inner,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.dark_mode_outlined, size: 16, color: pal.accent),
                  const SizedBox(width: 8),
                  Text('Dark mode',
                      style: TextStyle(fontSize: 11, color: pal.text)),
                ],
              ),
              Icon(Icons.toggle_on_rounded, color: pal.accent, size: 26),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // About Section Highlight
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pal.accentFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: pal.onAccentFill,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'About PipSpeak Section',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: pal.onAccentFill,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your companion app towards better public speaking and confidence.',
                  style: TextStyle(
                    fontSize: 11,
                    color: pal.onAccentFill.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version 1.0.0 • Hackathon Edition',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: pal.onAccentFill,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
