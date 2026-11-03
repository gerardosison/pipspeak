import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_router.dart';
import '../../../core/models/user_profile.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.location = AppRoutes.home, this.child});

  final String location;
  final Widget? child;

  int get _selectedIndex {
    if (location.startsWith('/documents')) return 1;
    if (location.startsWith('/practice')) return 2;
    if (location == AppRoutes.progress ||
        location == AppRoutes.history ||
        location == AppRoutes.rehearsalAnalysis ||
        location.startsWith('/feedback') ||
        location.startsWith('/reward')) {
      return 3;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location == AppRoutes.about) {
      return 4;
    }
    return 0;
  }

  static const _destinations = [
    AppRoutes.home,
    AppRoutes.documentUpload,
    AppRoutes.practice,
    AppRoutes.progress,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final shortWindow = constraints.maxHeight < 480;
      final extendedRail = constraints.maxWidth >= 1240;
      final hideNavigation = location == AppRoutes.practiceProcessing;
      // GoRouter's ShellRoute child is a keyed Navigator. Keep it mounted only
      // once; AnimatedSwitcher would retain the outgoing Navigator while the
      // incoming route is mounted, which duplicates its GlobalKey.
      final routeContent = child ?? const HomeLandingScreen();

      return Scaffold(
        body: hideNavigation
            ? routeContent
            : wide && shortWindow
            ? Column(
                children: [
                  NavigationBar(
                    height: 72,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) =>
                        context.go(_destinations[index]),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description_rounded),
                        label: 'Documents',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.mic_none_rounded),
                        selectedIcon: Icon(Icons.mic_rounded),
                        label: 'Practice',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.trending_up_rounded),
                        label: 'Progress',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                  Expanded(child: routeContent),
                ],
              )
            : wide
            ? Row(
                children: [
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          context.go(_destinations[index]),
                      extended: extendedRail,
                      labelType: extendedRail
                          ? null
                          : NavigationRailLabelType.all,
                      minExtendedWidth: 208,
                      groupAlignment: -0.8,
                      leading: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 28),
                        child: extendedRail
                            ? Text(
                                'PipSpeak',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              )
                            : const Icon(Icons.record_voice_over_rounded),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.description_outlined),
                          selectedIcon: Icon(Icons.description_rounded),
                          label: Text('Documents'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.mic_none_rounded),
                          selectedIcon: Icon(Icons.mic_rounded),
                          label: Text('Practice'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.trending_up_rounded),
                          selectedIcon: Icon(Icons.trending_up_rounded),
                          label: Text('Progress'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: Text('Profile'),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: routeContent),
                ],
              )
            : routeContent,
        bottomNavigationBar: wide || hideNavigation
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                      const BoxShadow(
                        color: Color.fromRGBO(255, 255, 255, 0.55),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 70,
                      child: Row(
                        children: [
                          _destination(context, 0, Icons.home_outlined, 'Home'),
                          _destination(
                            context,
                            1,
                            Icons.description_outlined,
                            'Documents',
                          ),
                          _destination(context, 2, Icons.mic_rounded, 'Practice'),
                          _destination(
                            context,
                            3,
                            Icons.trending_up_rounded,
                            'Progress',
                          ),
                          _destination(
                            context,
                            4,
                            Icons.person_outline_rounded,
                            'Profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
    },
  );

  Widget _destination(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = index == _selectedIndex;
    final colors = Theme.of(context).colorScheme;
    if (index == 2) {
      return Expanded(
        child: Transform.translate(
          offset: const Offset(0, -5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(_destinations[index]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [AppColors.sky, AppColors.secondary]
                          : [AppColors.primaryContainer, AppColors.navyDeep],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (selected ? AppColors.secondary : AppColors.navy)
                            .withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: InkWell(
        onTap: () => context.go(_destinations[index]),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeLandingScreen extends ConsumerWidget {
  const HomeLandingScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingSyncCountProvider).valueOrNull ?? 0;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          pending > 0
              ? '$pending session(s) have not synced yet. They stay saved on '
                    'this device and will upload next time you sign in here.'
              : 'You can come back anytime and continue your speaking journey.',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Stay here',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Log out',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: pipAppBar(
      context,
      title: 'PipSpeak',
      showBack: false,
      centerTitle: false,
      titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
      actions: [
        IconButton(
          tooltip: 'Log out',
          onPressed: () => _confirmLogout(context, ref),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: const _HomeTabView(),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// TAB 0: HOME
// -----------------------------------------------------------------------------
class _HomeTabView extends ConsumerWidget {
  const _HomeTabView();

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(currentUserProvider) ?? const UserProfile.placeholder();
    final level = ref.watch(levelStatusProvider);
    final records = ref.watch(genuineRecordsProvider);
    final sync = ref.watch(syncLabelProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final last = records.isEmpty ? null : records.first;
    final invite = records.isEmpty
        ? 'Record your first speech to set your baseline. Stars start '
              'with your next improvement.'
        : user.streakDays > 0
        ? 'You are on a ${user.streakDays}-day streak. Keep it going '
              'with one more practice today.'
        : 'Ready for a small win today? Jump back into practice.';

    final practiceCard = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? scheme.primaryContainer : AppColors.navy,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              records.isEmpty ? 'FIRST SPEECH' : "TODAY'S PRACTICE",
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Practice for: ${user.goal}',
            style: TextStyle(
              color: dark ? scheme.onPrimaryContainer : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            last == null
                ? 'Speak for a minute or two. Pip measures pace, filler '
                      'words and posture on this device.'
                : 'Last session: ${(last.overallScore ?? 0).round()}/100 '
                      'score, ${(last.wordsPerMinute ?? 0).round()} wpm, '
                      '${last.fillerCount ?? 0} fillers. Beat it today!',
            style: TextStyle(
              color: (dark ? scheme.onPrimaryContainer : Colors.white)
                  .withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.navy,
            ),
            onPressed: () => context.go(AppRoutes.practiceSetup),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Start practicing'),
          ),
        ],
      ),
    );
    final statsRow = Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '${user.streakDays}',
            label: 'Day streak',
            icon: Icons.local_fire_department_rounded,
            color: AppColors.sky,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            title: '${user.totalSessions}',
            label: 'Sessions completed',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.mint,
          ),
        ),
      ],
    );
    final progressCard = Card(
      child: ListTile(
        leading: const Icon(Icons.military_tech_rounded),
        title: Text('Level ${level.level} · ${level.totalStars} stars'),
        subtitle: Text(
          '${level.starsRemaining} more star(s) to Level ${level.level + 1}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(AppRoutes.progress),
      ),
    );
    final documentsCard = Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: const Text('Analyze a speech script'),
        subtitle: const Text('PDF, DOCX or TXT, processed on this device.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.documentUpload),
      ),
    );
    final coachCard = Card(
      child: ListTile(
        leading: const Icon(Icons.offline_bolt_rounded),
        title: const Text('Ask your local AI coach'),
        subtitle: const Text('Chat with Qwen on this device, even offline.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(AppRoutes.aiCoach),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_greeting(DateTime.now())}, ${user.nickname}!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              invite,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryText(context),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  sync.isError
                      ? Icons.cloud_off_rounded
                      : sync.text == 'Synced'
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_upload_outlined,
                  size: 18,
                  color: sync.isError ? scheme.error : scheme.primary,
                ),
                label: Text(sync.text),
                onPressed: sync.canRetry
                    ? () => ref.read(syncControllerProvider.notifier).syncNow()
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        practiceCard,
                        const SizedBox(height: 18),
                        statsRow,
                        const SizedBox(height: 8),
                        progressCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        documentsCard,
                        const SizedBox(height: 12),
                        coachCard,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              practiceCard,
              const SizedBox(height: 20),
              statsRow,
              const SizedBox(height: 14),
              progressCard,
              documentsCard,
              coachCard,
            ],
          ],
        );
      },
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHigh : color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? scheme.outlineVariant : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: dark ? scheme.primary : AppColors.navy, size: 24),
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
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}
