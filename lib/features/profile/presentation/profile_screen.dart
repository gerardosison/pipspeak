import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_chips.dart';
import 'widgets/delete_account_dialog.dart';

/// Profile tab — hero card, stats, account & preference
/// rows, logout / delete (Stitch `profile_tab`).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user =
        ref.watch(currentUserProvider) ?? const UserProfile.placeholder();

    return Scaffold(
      appBar: pipAppBar(
        context,
        title: 'Profile',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Hero card
                PipCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _ProfileAvatar(user: user, size: 72),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: text.headlineSmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                                if (user.nickname.isNotEmpty)
                                  Text(
                                    'Pip calls you ${user.nickname}',
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (user.username.isNotEmpty)
                                  Text(
                                    '@${user.username}',
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (user.email.isNotEmpty)
                                  Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    StarChip(label: 'Lv ${user.level} Orator'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _stat(
                              context,
                              '${ref.watch(levelStatusProvider).totalStars}',
                              'Stars',
                              AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _stat(
                              context,
                              '${user.streakDays}d',
                              'Streak',
                              AppColors.tertiaryFixed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _stat(
                              context,
                              '${user.totalSessions}',
                              'Speeches',
                              AppColors.secondaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                const _SectionLabel('ACCOUNT'),
                PipCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _row(
                        context,
                        Icons.edit_outlined,
                        'Edit Profile',
                        'Name, avatar & nickname',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      _row(
                        context,
                        Icons.lock_outline,
                        'Change Password',
                        'Keep your account secure',
                        onTap: () => context.push(AppRoutes.changePassword),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const _SectionLabel('PREFERENCES'),
                PipCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _row(
                        context,
                        Icons.tune,
                        'Settings',
                        'Theme, reminders & privacy',
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                      _row(
                        context,
                        Icons.shield_outlined,
                        'Privacy & Data',
                        'On-device processing & retention',
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextButton.icon(
                  onPressed: () => showDeleteAccountDialog(context, ref),
                  icon: Icon(Icons.delete_forever, color: scheme.error),
                  label: Text(
                    'Delete Account',
                    style: text.labelLarge?.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, Color tint) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: text.labelLarge?.copyWith(
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              IconDisc(icon: icon, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.labelLarge?.copyWith(color: scheme.onSurface),
                    ),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.size});

  final UserProfile user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocalPhoto = !kIsWeb && user.photoPath?.isNotEmpty == true;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondaryFixed.withValues(alpha: 0.6),
        border: Border.all(color: scheme.secondaryContainer, width: 3),
      ),
      child: ClipOval(
        child: hasLocalPhoto
            ? Image.file(
                File(user.photoPath!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(context),
              )
            : _initial(context),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final name = user.name.trim();
    return Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
