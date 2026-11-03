import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../../../core/widgets/pip_buttons.dart';
import '../../../core/widgets/pip_fields.dart';
import '../../../core/widgets/pip_mascot.dart';
import '../../../core/widgets/pip_misc.dart';

/// No Stitch design — built in the same design language.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      var email = _email.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        email = await ref
                .read(profileRepositoryProvider)
                .emailForUsername(email) ??
            '';
      }
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists, a reset link was sent to that email.',
          ),
        ),
      );
      context.pop();
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: pipAppBar(context, title: 'Reset Password'),
      body: Stack(
        children: [
          const AmbientBlobs(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Center(
                    child: PipMascot(
                      asset: PipAsset.sad,
                      size: 120,
                      showBadge: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Forgot your password?',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No worries! Enter your username or email and Pip will send a reset link your way.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(27, 42, 107, 0.08),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PipTextField(
                          controller: _email,
                          label: 'Username or Email',
                          hint: 'Enter your username or email',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: _busy ? 'Sending…' : 'Send Reset Link',
                          icon: Icons.send,
                          onPressed: _busy ? null : _send,
                        ),
                        const SizedBox(height: 10),
                        PipGhostButton(
                          label: 'Back to Log In',
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
