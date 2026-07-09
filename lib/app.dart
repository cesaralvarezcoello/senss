import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'design/app_theme.dart';
import 'features/moment/moment_screen.dart';

class SenssApp extends StatelessWidget {
  const SenssApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Pantalla principal = modo paciente ("Un momento"). El modo familia
      // (FeedScreen) se abre desde ahí con un gesto discreto y gateado.
      home: const MomentScreen(),
    );
  }
}
