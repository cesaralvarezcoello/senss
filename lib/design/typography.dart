import 'package:flutter/material.dart';

/// Escala tipográfica de senss. Fuentes grandes y legibles (adultos mayores),
/// con jerarquía cálida. Los estilos no llevan color: lo aplica [AppText]
/// según el tono, o el `TextTheme` según la superficie.
///
/// Para cambiar la fuente de TODA la app, define [fontFamily] aquí.
class AppType {
  /// Fuente global (null = fuente del sistema). Punto único de cambio.
  static const String? fontFamily = null;

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle titleL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle titleM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  /// Construye el `TextTheme` de Material a partir de la escala, para que los
  /// widgets estándar (que no usan [AppText]) también hereden la tipografía.
  static TextTheme textTheme(Color ink) => TextTheme(
        displaySmall: display,
        headlineSmall: titleL,
        titleLarge: titleL,
        titleMedium: titleM,
        bodyLarge: body,
        bodyMedium: caption.copyWith(fontSize: 16),
        labelLarge: label,
        labelSmall: overline,
      ).apply(bodyColor: ink, displayColor: ink);
}
