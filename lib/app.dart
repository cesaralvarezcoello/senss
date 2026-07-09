import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'design/app_theme.dart';
import 'features/moment/moment_screen.dart';
import 'state/profile_store.dart';

class SenssApp extends StatelessWidget {
  const SenssApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileStore>(
      create: (_) => ProfileStore()..load(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        // Escala global de texto según la edad del perfil (centralizado):
        // la tercera edad ve todo más grande, sin tocar cada pantalla.
        builder: (context, child) {
          final scale = context.watch<ProfileStore>().profile.textScale;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        // Pantalla principal = modo paciente ("Un momento"). El modo familia
        // (FeedScreen) se abre desde ahí con un gesto discreto y gateado.
        home: const MomentScreen(),
      ),
    );
  }
}
