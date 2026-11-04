import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../data/repositories/profile_repository.dart';
import '../services/auth_service.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/pip_misc.dart';

import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  bool _busy = false;

  /// Username most recently rejected by the server as already taken.
  String? _takenUsername;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isUsernameUnique =>
      ProfileRepository.isValidUsername(_usernameController.text) &&
      !_isUsernameTaken;

  bool get _isUsernameTaken =>
      _takenUsername != null &&
      ProfileRepository.normalizeUsername(_usernameController.text) ==
          _takenUsername;

  bool get _isPasswordValid => _passwordController.text.length >= 8;

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      if (_firstNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your first name to continue.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (_nicknameController.text.trim().isEmpty) {
        // If nickname empty, default to first name
        _nicknameController.text = _firstNameController.text.trim();
      }
      setState(() => _step = 2);
      return;
    }

    // Step 2 (Step 3 of 3): Validate username & password
    if (_isUsernameTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This username is already taken. Please pick another.'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    if (!_isUsernameUnique) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usernames use 3–20 lowercase letters, numbers, dots or underscores.',
          ),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    if (!AuthService.isValidEmail(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    // Proceed to Welcome Screen
    final nickname = _nicknameController.text.trim().isNotEmpty
        ? _nicknameController.text.trim()
        : (_firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : 'Speaker');

    final fullName = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    setState(() => _busy = true);
    try {
      await ref
          .read(authServiceProvider)
          .register(
            fullName: fullName,
            nickname: nickname,
            username: _usernameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error.message.contains('username is already taken')) {
          _takenUsername = ProfileRepository.normalizeUsername(
            _usernameController.text,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account could not be saved. Try signing in with your email before registering again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(AppRoutes.splash);
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await _showAnimatedExitDialog();
    if (shouldExit && mounted) {
      Navigator.of(context).pop();
      return true;
    }
    return false;
  }

  void _previous() async {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      await _confirmExit();
    }
  }

  /// Animated confirmation prompt asking whether to cancel registration or continue
  Future<bool> _showAnimatedExitDialog() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel Registration Confirmation',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.sky,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.navy,
                  size: 28,
                ),
              ),
              title: const Text(
                'Cancel Registration?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
              ),
              content: Text(
                'Are you sure you want to cancel your registration? Any progress entered will not be saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText(ctx),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                        child: const Text(
                          'Cancel registration',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Continue registration',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const stepTitles = [
      'Enter first name and last name',
      'Enter nickname',
      'Enter username and password',
    ];

    const stepSubtitles = [
      'Tell us your full name so we can personalize your training profile.',
      'A nickname makes your practice feel personal and friendly.',
      'Secure your account with a unique username and strong password.',
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        appBar: pipAppBar(
          context,
          title: 'Step ${_step + 1} of 3',
          onBack: _previous,
          actions: [
            TextButton(onPressed: _confirmExit, child: const Text('Cancel')),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress Track
                    Row(
                      children: List.generate(
                        3,
                        (index) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 6,
                            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                            decoration: BoxDecoration(
                              color: index <= _step
                                  ? AppColors.blue
                                  : AppColors.line,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Step Badge
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sky,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Step ${_step + 1} of 3',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step Title
                    Text(
                      stepTitles[_step],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stepSubtitles[_step],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // STEP 1: Enter first name and last name
                    if (_step == 0) ...[
                      TextField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          hintText: 'e.g. Alex',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          hintText: 'e.g. Morgan',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ]
                    // STEP 2: Enter nickname
                    else if (_step == 1) ...[
                      TextField(
                        controller: _nicknameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          hintText: 'e.g. Lexie, Capt, Ace',
                          prefixIcon: Icon(Icons.auto_awesome_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: AppColors.blue,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This is how PipSpeak will warmly address you throughout your speech journey.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // STEP 3: Enter username and password (with indicators)
                    else ...[
                      TextField(
                        controller: _usernameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. alex_speaks',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      // Added spacing between field and small text indicator
                      const SizedBox(height: 14),
                      // Username uniqueness indicator
                      _UsernameIndicator(
                        isTaken: _isUsernameTaken,
                        isUnique: _isUsernameUnique,
                        text: _usernameController.text.trim(),
                      ),
                      const SizedBox(height: 22),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'e.g. alex@school.edu',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 22),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter at least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      // Added spacing between field and small text indicator
                      const SizedBox(height: 14),
                      // Password 8 min characters indicator
                      _PasswordIndicator(
                        length: _passwordController.text.length,
                        isValid: _isPasswordValid,
                      ),
                    ],

                    const SizedBox(height: 36),

                    // Actions
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _next,
                        child: Text(
                          _busy
                              ? 'Creating account…'
                              : (_step == 2 ? 'Create account' : 'Continue'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (_step > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: TextButton(
                          onPressed: _previous,
                          child: const Text('Back to previous step'),
                        ),
                      ),
                    ],
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

/// Indicator for username uniqueness requirement
class _UsernameIndicator extends StatelessWidget {
  const _UsernameIndicator({
    required this.isTaken,
    required this.isUnique,
    required this.text,
  });

  final bool isTaken;
  final bool isUnique;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.secondaryText(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Username must be unique (min 3 chars)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText(context),
              ),
            ),
          ),
        ],
      );
    }

    if (isTaken) {
      return Row(
        children: [
          Icon(
            Icons.cancel_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Username is already taken - choose another',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (isUnique) {
      return const Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Username is unique and available!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.secondaryText(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Username must be at least 3 characters',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Indicator for password 8 min characters requirement
class _PasswordIndicator extends StatelessWidget {
  const _PasswordIndicator({required this.length, required this.isValid});

  final int length;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final color = isValid
        ? Colors.green
        : (length > 0 ? AppColors.coral : AppColors.secondaryText(context));
    final icon = isValid
        ? Icons.check_circle_rounded
        : (length > 0
              ? Icons.error_outline_rounded
              : Icons.info_outline_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isValid
                    ? 'Password meets requirement (8+ min characters)'
                    : 'Password must be 8 min characters ($length/8)',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (length / 8).clamp(0.0, 1.0),
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation<Color>(
              isValid
                  ? Colors.green
                  : (length >= 4 ? AppColors.yellow : AppColors.coral),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
