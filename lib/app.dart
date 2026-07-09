import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'design/app_theme.dart';
import 'features/moment/moment_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'state/profile_store.dart';

class SenssApp extends StatelessWidget {
  const SenssApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileStore>(
      create: (_) => ProfileStore()..load(),
      // Consumer envuelve toda la MaterialApp: al cambiar el perfil se
      // reconstruye y aplica la nueva escala de texto (edad) en toda la app.
      child: Consumer<ProfileStore>(
        builder: (context, store, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(store.profile.textScale),
                ),
                child: child!,
              );
            },
            home: !store.loaded
                ? const ColoredBox(
                    color: Color(0xFF0E0A07),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE08A2E)),
                    ),
                  )
                : (store.profile.onboarded
                    ? const MomentScreen()
                    : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}
