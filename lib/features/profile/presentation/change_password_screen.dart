import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_cards.dart';
import '../../../core/widgets/pip_fields.dart';
import '../../../core/widgets/pip_misc.dart';
import '../../auth/services/auth_service.dart';

/// Change Password — re-authenticates with Firebase, then updates it.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_next.text != _confirm.text) {
      _show('The new passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .changePassword(_current.text, _next.text);
      if (!mounted) return;
      _show('Password updated.');
      context.pop();
    } on AuthFailure catch (error) {
      if (mounted) _show(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: pipAppBar(context, title: 'Change Password'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                PipCard(
                  child: Column(
                    children: [
                      PipTextField(
                        controller: _current,
                        label: 'Current Password',
                        hint: 'Enter current password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 14),
                      PipTextField(
                        controller: _next,
                        label: 'New Password',
                        hint: 'At least 8 characters',
                        icon: Icons.key,
                        isPassword: true,
                      ),
                      const SizedBox(height: 14),
                      PipTextField(
                        controller: _confirm,
                        label: 'Confirm New Password',
                        hint: 'Re-enter new password',
                        icon: Icons.verified_user_outlined,
                        isPassword: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _busy ? 'Updating…' : 'Update Password',
                  icon: Icons.check,
                  onPressed: _busy ? null : _submit,
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
}
