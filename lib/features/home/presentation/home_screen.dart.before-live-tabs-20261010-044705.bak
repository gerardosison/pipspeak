import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/login_screen.dart';
import '../../practice/presentation/setup_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;

  final _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.insights_rounded, label: 'Progress'),
    _NavItem(icon: Icons.mic_rounded, label: 'Practice'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    _NavItem(icon: Icons.tune_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content area with bottom padding so floating nav bar does not overlap
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                child: _buildCurrentTab(context),
              ),
            ),

            // Bottom-anchored floating rounded navigation bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _FloatingNavBar(
                items: _navItems,
                selectedIndex: _selected,
                onSelected: (index) => setState(() => _selected = index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context) {
    late final Widget content;
    switch (_selected) {
      case 0:
        content = const SizedBox.shrink();
        break;
      case 1:
        content = const SizedBox.shrink();
        break;
      case 2:
        content = _PracticeTabView(
          onStart: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            );
          },
        );
        break;
      case 3:
        content = const SizedBox.shrink();
        break;
      case 4:
        content = const _SettingsTabView();
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeHeaderOnly(onLogout: _showLogoutPrompt),
        if (_selected != 0) const SizedBox(height: 28),
        content,
      ],
    );
  }

  Future<void> _showLogoutPrompt() async {
    final shouldLogout = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close logout confirmation',
      barrierColor: AppColors.navy.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You can come back anytime and continue your speaking journey.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );

    if (shouldLogout == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _HomeHeaderOnly extends StatelessWidget {
  const _HomeHeaderOnly({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'VOICE MATE',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          letterSpacing: 1.8,
          fontWeight: FontWeight.w900,
        ),
      ),
      IconButton(
        onPressed: onLogout,
        tooltip: 'Log out',
        style: IconButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.sky,
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
      ),
    ],
  );
}

/// Bottom-anchored floating rounded navigation bar
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2214213D),
            blurRadius: 20,
            spreadRadius: 1,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;
          final isPractice = index == 2; // Middle item: Practice

          if (isPractice) {
            // Reserve the same horizontal slot as the other items, then lift
            // the large control above the bar without changing its layout.
            return Expanded(
              child: Transform.translate(
                offset: const Offset(0, 0),
                child: GestureDetector(
                  onTap: () => onSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.blue : AppColors.navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isSelected ? AppColors.blue : AppColors.navy)
                                      .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: Colors.white, size: 34),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Other 4 navigation items: Home, Progress, Profile, Settings
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.sky : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: isSelected ? AppColors.navy : AppColors.navySoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected ? AppColors.navy : AppColors.navySoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 0: HOME
// -----------------------------------------------------------------------------
class _HomeTabView extends StatelessWidget {
  const _HomeTabView({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'VOICE MATE',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.navy, width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '7 DAYS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onLogout,
                  tooltip: 'Log out',
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    backgroundColor: AppColors.sky,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Good morning, speaker!',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ready for a small win today? Take on today’s speech exercise.',
          style: TextStyle(fontSize: 15, color: AppColors.navySoft),
        ),
        const SizedBox(height: 24),

        // Warm up card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1814213D),
                offset: Offset(4, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "TODAY'S WARM-UP",
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tell a story in 60 seconds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice structuring a beginning, middle, and climax with natural pacing.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stat cards
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                title: '7',
                label: 'Day streak',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.sky,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                title: '12',
                label: 'Sessions completed',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.mint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String title;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.navy, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.navySoft),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: PROGRESS
// -----------------------------------------------------------------------------
class _ProgressTabView extends StatelessWidget {
  const _ProgressTabView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Progress', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text(
          'Track your speech metrics, pacing trends, and consistency.',
          style: TextStyle(color: AppColors.navySoft),
        ),
        const SizedBox(height: 24),

        // Fluency score card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '88%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Fluency Score',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '+5% improvement since last week. Excellent pacing consistency.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.navySoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metrics breakdown
        const _MetricRow(label: 'Clarity & Articulation', score: '91%'),
        const SizedBox(height: 10),
        const _MetricRow(label: 'Pacing (135 words/min)', score: '88%'),
        const SizedBox(height: 10),
        const _MetricRow(label: 'Minimal Filler Words', score: '85%'),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.score});

  final String label;
  final String score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            score,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: PRACTICE (EMPHASIZED MIDDLE ITEM)
// -----------------------------------------------------------------------------
class _PracticeTabView extends StatelessWidget {
  const _PracticeTabView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Practice Studio',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Select a format and start recording your speech session.',
          style: TextStyle(color: AppColors.navySoft),
        ),
        const SizedBox(height: 28),

        // Mic recording centerpiece
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x404F7CFF),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ready to Record',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI real-time coaching will analyze your tempo & clarity.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.navySoft),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onStart,
                  child: const Text('Start Live Practice'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: PROFILE
// -----------------------------------------------------------------------------
class _ProfileTabView extends StatelessWidget {
  const _ProfileTabView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Profile', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text('Your speaker stats, rank, and achievements.'),
        const SizedBox(height: 24),

        // User badge card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.navy, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speaker Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Level 4: Eloquent Speaker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navySoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Badges container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BADGES & MILESTONES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                ),
              ),
              SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Badge(icon: '🏅', name: '7-Day Streak'),
                  _Badge(icon: '🎙️', name: '10+ Speeches'),
                  _Badge(icon: '⭐', name: '90% Clarity'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.name});
  final String icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: SETTINGS (WITH ABOUT SECTION)
// -----------------------------------------------------------------------------
class _SettingsTabView extends StatelessWidget {
  const _SettingsTabView();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
