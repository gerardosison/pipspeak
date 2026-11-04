import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_router.dart';
import '../services/auth_service.dart';

import '../../../app/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _formOpen = false;
  bool _busy = false;

  /// Plays once when the screen first appears (logo pops in, text fades in).
  late final AnimationController _entrance;

  /// Drives EVERYTHING that changes when "Begin" is tapped (hero position,
  /// Begin button collapse, form rising, mountain parallax). One controller
  /// means every piece stays perfectly in sync.
  late final AnimationController _form;

  /// Slow looping controller for clouds drifting and the logo bobbing.
  late final AnimationController _ambient;

  late final Animation<double> _formCurve;
  late final Animation<double> _beginFade;
  late final Animation<double> _beginSize;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<double> _beginEntrance;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _form = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _formCurve = CurvedAnimation(parent: _form, curve: Curves.easeInOutCubic);

    _beginFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _form,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
    );
    _beginSize = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _form,
        curve: const Interval(0, 0.8, curve: Curves.easeInOutCubic),
      ),
    );

    _logoScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.6, curve: Curves.elasticOut),
    );
    _textFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );
    _beginEntrance = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _entrance.dispose();
    _form.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _openForm() {
    setState(() => _formOpen = true);
    _form.forward();
  }

  void _closeForm() {
    FocusScope.of(context).unfocus();
    setState(() => _formOpen = false);
    _form.reverse();
  }

  Future<void> _onLogin() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(_usernameController.text, _passwordController.text);
      final profile = await ref.read(profileRepositoryProvider).get(user.uid);
      if (!mounted) return;
      if (profile?.onboardingComplete ?? false) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.splash);
      }
    } on AuthFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        'Your account could not be opened. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.coral),
    );
  }

  void _onRegister() {
    context.push(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      // While the form is open, the system back gesture closes it first.
      canPop: !_formOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeForm();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2E8BDF),
        // The background must not squash when the keyboard opens; the content
        // handles the keyboard inset itself below.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MountainPainter(
                    ambient: _ambient,
                    progress: _formCurve,
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: insets),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = math.max(constraints.maxHeight, 620.0);
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        height: height,
                        child: Stack(
                          children: [
                            // Hero: positioned from the top so it only drifts
                            // a short distance (from just above the middle to
                            // the upper-middle) when the form opens.
                            AnimatedBuilder(
                              animation: _formCurve,
                              builder: (context, child) {
                                const heroHeight = 190.0;
                                const formHeight = 500.0;
                                final bottomSafe = MediaQuery.of(context)
                                    .padding
                                    .bottom;
                                final topStart =
                                    (height * 0.38 - heroHeight / 2).clamp(
                                      8.0,
                                      double.infinity,
                                    );
                                final maxTop = math.max(
                                  8.0,
                                  height -
                                      formHeight -
                                      bottomSafe -
                                      heroHeight -
                                      12,
                                );
                                final topEnd = (height * 0.26 - heroHeight / 2)
                                    .clamp(8.0, maxTop);
                                final top =
                                    topStart +
                                    (topEnd - topStart) * _formCurve.value;
                                return Positioned(
                                  top: top,
                                  left: 0,
                                  right: 0,
                                  child: child!,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: _hero(),
                              ),
                            ),

                            // Bottom stack: Begin sits on the bottom edge and
                            // is replaced by the form rising from the same edge.
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _beginButton(
                                    MediaQuery.of(context).padding.bottom,
                                  ),
                                  SizeTransition(
                                    sizeFactor: _formCurve,
                                    alignment: Alignment.bottomCenter,
                                    child: _loginForm(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- hero

  Widget _hero() {
    const textShadow = [
      Shadow(color: Color(0x6614213D), offset: Offset(0, 2), blurRadius: 6),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo: pops in, then gently bobs.
        ScaleTransition(
          scale: _logoScale,
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                math.sin(_ambient.value * 2 * math.pi * 12) * 4,
              ),
              child: child,
            ),
            child: const _Logo(),
          ),
        ),
        const SizedBox(height: 12),

        FadeTransition(
          opacity: _textFade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_textFade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PipSpeak',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w800,
                    fontSize: 64,
                    color: Colors.white,
                    shadows: textShadow,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your companion app towards better public speaking and confidence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
                    shadows: textShadow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Begin button anchored to the bottom of the screen. It fades and
  /// collapses while the form rises from the same edge.
  Widget _beginButton(double bottomSafe) {
    return SizeTransition(
      sizeFactor: _beginSize,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: _beginFade,
        child: FadeTransition(
          opacity: _beginEntrance,
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 16, 32, 28 + bottomSafe),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _formOpen ? null : _openForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                  disabledBackgroundColor: Colors.white,
                  disabledForegroundColor: AppColors.navy,
                  elevation: 0,
                ),
                child: const Text(
                  'Begin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- form

  /// Staggered reveal for each form row: fades and slides up in sequence.
  Widget _reveal(double start, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _form,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Widget _loginForm(BuildContext context) {
    final media = MediaQuery.of(context);
    // Respect the home-indicator inset, but not while the keyboard is open.
    final bottomSafe = media.viewInsets.bottom > 0 ? 0.0 : media.padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, 18, 32, 28 + bottomSafe),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2214213D),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _reveal(
            0.35,
            0.7,
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 18),

          _reveal(
            0.42,
            0.78,
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username or email',
                hintText: 'Enter username or email',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _reveal(
            0.5,
            0.85,
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onLogin(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ),

          _reveal(
            0.58,
            0.9,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.forgotPassword),
                child: const Text('Forgot password?'),
              ),
            ),
          ),
          const SizedBox(height: 8),

          _reveal(
            0.64,
            0.95,
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _busy ? 'Signing in…' : 'Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _reveal(
            0.7,
            1.0,
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _onRegister,
                child: const Text(
                  'Register',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square PipSpeak logo.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.sky, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x3314213D),
          offset: Offset(3, 5),
          blurRadius: 0,
        ),
      ],
    ),
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/logo.png',
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          semanticLabel: 'PipSpeak logo',
        ),
      ),
    ),
  );
}

/// Cartoon mountain scene: sky gradient, sunrise, drifting clouds, layered
/// snow-capped peaks, rolling hills and pine trees. Everything is drawn with
/// a thick round-joined stroke so corners look soft and "sticker-like".
class _MountainPainter extends CustomPainter {
  _MountainPainter({required this.ambient, required this.progress})
    : super(repaint: Listenable.merge([ambient, progress]));

  final Animation<double> ambient;
  final Animation<double> progress;

  // Palette
  static const _skyTop = Color(0xFF2E8BDF);
  static const _skyMid = Color(0xFF6EC1F5);
  static const _skyLow = Color(0xFFBDE8FF);
  static const _farPeak = Color(0xFFA9B8F0);
  static const _midPeak = Color(0xFF7B93E6);
  static const _snow = Color(0xFFF4F9FF);
  static const _hillBack = Color(0xFF7BD63A);
  static const _hillFront = Color(0xFF58CC02); // Duolingo-style green
  static const _pine = Color(0xFF2E9E4F);
  static const _pineDark = Color(0xFF237C3D);
  static const _trunk = Color(0xFF8B5E3C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = ambient.value;
    final p = progress.value;

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyMid, _skyLow],
          stops: [0.0, 0.5, 0.85],
        ).createShader(Offset.zero & size),
    );

    // Sunrise peeking from behind the far mountains
    final sunCenter = Offset(w * 0.78, h * 0.5 - p * 14);
    for (final ring in const [
      [72.0, 0x14FFFFFF],
      [54.0, 0x22FFFFFF],
      [40.0, 0x33FFFFFF],
    ]) {
      canvas.drawCircle(
        sunCenter,
        ring[0] as double,
        Paint()..color = Color(ring[1] as int),
      );
    }
    canvas.drawCircle(sunCenter, 32, Paint()..color = const Color(0xFFFFE066));

    // Drifting clouds (speeds are multiples of the wrap width so the loop
    // is seamless).
    const clouds = [
      // x, y, scale, speed, color
      [0.10, 0.47, 1.0, 1.3, 0xFFFFFFFF],
      [0.62, 0.53, 0.75, 2.6, 0xFFF0F9FF],
      [0.95, 0.58, 0.9, 1.3, 0xFFFFFFFF],
    ];
    for (final c in clouds) {
      final x = (((c[0] as double) + t * (c[3] as double)) % 1.3 - 0.2) * w;
      _cloud(
        canvas,
        x,
        h * (c[1] as double) - p * 8,
        c[2] as double,
        Color(c[4] as int),
      );
    }

    // Far peaks (slowest parallax)
    canvas.save();
    canvas.translate(0, -p * 8);
    _mountain(canvas, size, 0.18, 0.52, 0.30, _farPeak);
    _mountain(canvas, size, 0.55, 0.46, 0.34, _farPeak);
    _mountain(canvas, size, 0.92, 0.54, 0.30, _farPeak);
    canvas.restore();

    // Mid peaks
    canvas.save();
    canvas.translate(0, -p * 14);
    _mountain(canvas, size, 0.02, 0.62, 0.30, _midPeak);
    _mountain(canvas, size, 0.40, 0.58, 0.28, _midPeak);
    _mountain(canvas, size, 0.80, 0.64, 0.32, _midPeak);
    canvas.restore();

    // Back hill + trees
    double backY(double x) =>
        h * (0.80 + 0.025 * math.sin(x / w * math.pi * 2 + 1)) - p * 18;
    _hill(canvas, size, backY, _hillBack);
    for (final tr in const [
      [0.08, 0.9],
      [0.16, 0.7],
      [0.64, 0.8],
      [0.90, 1.0],
    ]) {
      _pineTree(canvas, w * tr[0], backY(w * tr[0]) + 4, tr[1], _pine);
    }

    // Front hill + trees
    double frontY(double x) =>
        h * (0.89 + 0.02 * math.sin(x / w * math.pi * 2.4 + 3)) - p * 24;
    _hill(canvas, size, frontY, _hillFront);
    for (final tr in const [
      [0.22, 1.1],
      [0.30, 0.8],
      [0.78, 1.2],
      [0.86, 0.85],
    ]) {
      _pineTree(canvas, w * tr[0], frontY(w * tr[0]) + 4, tr[1], _pineDark);
    }
  }

  void _cloud(Canvas c, double x, double y, double s, Color color) {
    final paint = Paint()..color = color;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 90 * s, 26 * s),
        Radius.circular(13 * s),
      ),
      paint,
    );
    c.drawCircle(Offset(x + 30 * s, y + 4 * s), 18 * s, paint);
    c.drawCircle(Offset(x + 55 * s, y - 2 * s), 22 * s, paint);
  }

  void _mountain(
    Canvas c,
    Size s,
    double cx,
    double peak,
    double halfWidth,
    Color color,
  ) {
    final x = cx * s.width;
    final py = peak * s.height;
    final half = halfWidth * s.width;
    final by = s.height * 0.95;

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(x - half, by)
      ..lineTo(x, py)
      ..lineTo(x + half, by)
      ..close();
    c.drawPath(body, fill);
    c.drawPath(body, stroke);

    // Snow cap with a zigzag lower edge. Its edges follow the mountain's, so
    // the round-joined stroke blends into the mountain outline.
    const t = 0.3;
    final capY = py + (by - py) * t;
    final dx = half * t;
    final d = (by - py) * 0.06;
    final cap = Path()
      ..moveTo(x, py)
      ..lineTo(x + dx, capY)
      ..lineTo(x + dx * 0.5, capY + d)
      ..lineTo(x, capY + d * 0.1)
      ..lineTo(x - dx * 0.45, capY + d)
      ..lineTo(x - dx, capY)
      ..close();
    c.drawPath(cap, Paint()..color = _snow);
    c.drawPath(
      cap,
      Paint()
        ..color = _snow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _hill(Canvas c, Size s, double Function(double) yAt, Color color) {
    final path = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width + 6; x += 6) {
      path.lineTo(x, yAt(x));
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  void _pineTree(Canvas c, double x, double baseY, double s, Color leaf) {
    // Trunk
    c.drawRect(
      Rect.fromLTWH(x - 3 * s, baseY - 10 * s, 6 * s, 12 * s),
      Paint()..color = _trunk,
    );

    final fill = Paint()..color = leaf;
    final stroke = Paint()
      ..color = leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeJoin = StrokeJoin.round;

    // Three stacked tiers, bottom to top.
    for (var i = 0; i < 3; i++) {
      final tierBase = baseY - 8 * s - i * 14 * s;
      final tierHalf = (15 - i * 3.5) * s;
      final tier = Path()
        ..moveTo(x - tierHalf, tierBase)
        ..lineTo(x, tierBase - 24 * s)
        ..lineTo(x + tierHalf, tierBase)
        ..close();
      c.drawPath(tier, fill);
      c.drawPath(tier, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) => false;
}
