import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'features/auth/presentation/login_screen.dart';

void main() => runApp(const VoiceMateApp());

class VoiceMateApp extends StatelessWidget {
  const VoiceMateApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, themeMode, _) => MaterialApp(
      title: 'Voice Mate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const LoginScreen(),
    ),
  );
}

typedef MyApp = VoiceMateApp;
