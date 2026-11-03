import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_fields.dart';
import '../../../core/widgets/pip_misc.dart';

/// Edit Profile — avatar, name and nickname fields, account identity,
/// save/cancel (Stitch `edit_profile`).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _nickname;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider) ?? const UserProfile.placeholder();
    _name = TextEditingController(text: u.name);
    _nickname = TextEditingController(text: u.nickname);
    _name.addListener(_refreshAvatar);
  }

  @override
  void dispose() {
    _name.removeListener(_refreshAvatar);
    for (final c in [_name, _nickname]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refreshAvatar() {
    if (mounted) setState(() {});
  }

  Future<void> _save(UserProfile user) async {
    if (user.uid.isEmpty) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(
            userId: user.uid,
            fullName: _name.text,
            nickname: _nickname.text,
            language: user.language,
            practicePurpose: user.goal,
            onboardingComplete: true,
          );
      ref.read(syncControllerProvider.notifier).syncNow();
      if (mounted) context.pop();
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${error.message}')));
      }
    }
  }

  Future<void> _pickPhoto(UserProfile user) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked == null || user.uid.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, 'profile_${user.uid}.jpg'));
    await File(picked.path).copy(target.path);
    await ref
        .read(profileRepositoryProvider)
        .setPhotoPath(user.uid, target.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo saved on this device (not uploaded).'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user =
        ref.watch(currentUserProvider) ?? const UserProfile.placeholder();

    return Scaffold(
      appBar: pipAppBar(context, title: 'Edit Profile'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Avatar
                Center(
                  child: Semantics(
                    button: !kIsWeb,
                    label: kIsWeb ? null : 'Change profile photo',
                    child: GestureDetector(
                      onTap: kIsWeb ? null : () => _pickPhoto(user),
                      child: Stack(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondaryFixed.withValues(
                                alpha: 0.5,
                              ),
                              border: Border.all(
                                color: scheme.secondaryContainer,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: !kIsWeb &&
                                      user.photoPath?.isNotEmpty == true
                                  ? Image.file(
                                      File(user.photoPath!),
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _avatarInitial(text, scheme),
                                    )
                                  : _avatarInitial(text, scheme),
                            ),
                          ),
                          if (!kIsWeb)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.primary,
                                  border: Border.all(
                                    color: scheme.surfaceContainerLowest,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_camera,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    kIsWeb
                        ? 'Profile photos are available in the installed app'
                        : 'Tap to change avatar',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                PipCard(
                  child: Column(
                    children: [
                      PipTextField(
                        label: 'Full Name',
                        hint: 'Your full name',
                        icon: Icons.badge_outlined,
                        controller: _name,
                      ),
                      const SizedBox(height: 14),
                      PipTextField(
                        label: 'Nickname',
                        hint: 'What Pip should call you',
                        icon: Icons.alternate_email,
                        controller: _nickname,
                      ),
                      const SizedBox(height: 14),
                      if (user.email.isNotEmpty || user.username.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (user.email.isNotEmpty) user.email,
                            if (user.username.isNotEmpty)
                              '@${user.username}',
                          ].join(' • '),
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Email and username are linked to your account and '
                          'cannot be edited here.',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!kIsWeb) ...[
                  PipGhostButton(
                    label: 'Change profile photo',
                    onPressed: () => _pickPhoto(user),
                  ),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'Save Changes',
                  icon: Icons.check,
                  onPressed: () => _save(user),
                ),
                const SizedBox(height: 8),
                PipGhostButton(label: 'Cancel', onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarInitial(TextTheme text, ColorScheme scheme) {
    final name = _name.text.trim();
    return Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: text.displayLarge?.copyWith(fontSize: 40, color: scheme.primary),
      ),
    );
  }
}
