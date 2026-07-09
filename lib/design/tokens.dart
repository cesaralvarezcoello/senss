import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SISTEMA DE DISEÑO — única fuente de verdad de los estilos de senss.
///
/// Todo (colores, tipografía, espaciados, radios, sombras, movimiento) se
/// define aquí. Los componentes de `lib/design/components/` leen estos tokens,
/// así que cambiar un valor re-estiliza toda la app de forma centralizada.
/// ---------------------------------------------------------------------------

/// Paleta semántica. Se define por tema (claro/oscuro) y se expone vía
/// [AppTokens]. Los colores por emoción viven en `core/emotions.dart`.
class AppColors {
  final Color bg; // fondo de la pantalla
  final Color surface; // superficie base
  final Color surfaceSoft; // superficie sutil (chips, campos)
  final Color surfaceHigh; // tarjetas elevadas
  final Color ink; // texto principal
  final Color inkSoft; // texto secundario
  final Color inkFaint; // texto terciario / deshabilitado
  final Color line; // bordes y divisores
  final Color accent; // acción principal
  final Color onAccent; // contenido sobre el acento
  final Color danger; // acción destructiva
  final Color onDanger;
  final List<BoxShadow> cardShadow;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceHigh,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.onDanger,
    required this.cardShadow,
  });

  static const light = AppColors(
    bg: Color(0xFFFBF5EE),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF4EADF),
    surfaceHigh: Color(0xFFFFFFFF),
    ink: Color(0xFF2B2320),
    inkSoft: Color(0xFF6F6259),
    inkFaint: Color(0xFFA2938A),
    line: Color(0xFFEADFD3),
    accent: Color(0xFFE08A2E),
    onAccent: Color(0xFF3A2A12),
    danger: Color(0xFFB4453D),
    onDanger: Color(0xFFFFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x14261A0E), blurRadius: 24, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  static const dark = AppColors(
    bg: Color(0xFF14100D),
    surface: Color(0xFF1E1712),
    surfaceSoft: Color(0xFF2A211A),
    surfaceHigh: Color(0xFF241C16),
    ink: Color(0xFFF4EAE0),
    inkSoft: Color(0xFFB7A89B),
    inkFaint: Color(0xFF7E7064),
    line: Color(0xFF33291F),
    accent: Color(0xFFF0A344),
    onAccent: Color(0xFF2B1B08),
    danger: Color(0xFFE0736A),
    onDanger: Color(0xFF2B0F0C),
    cardShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 14)),
    ],
  );
}

/// Escala de espaciado (múltiplos de 4). No cambia por tema.
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios de esquina.
class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

/// Duraciones de movimiento.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

/// Extensión de tema que transporta la paleta. Los componentes la leen con
/// `context.colors`. La conmutación de tema es instantánea (lerp = elige).
class AppTokens extends ThemeExtension<AppTokens> {
  final AppColors colors;
  const AppTokens(this.colors);

  static const lightTokens = AppTokens(AppColors.light);
  static const darkTokens = AppTokens(AppColors.dark);

  @override
  AppTokens copyWith({AppColors? colors}) => AppTokens(colors ?? this.colors);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Acceso ergonómico a los tokens desde cualquier `BuildContext`.
extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.lightTokens;
  AppColors get colors => tokens.colors;
}
