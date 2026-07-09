import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Construye el `ThemeData` de senss a partir de los tokens. Registra
/// [AppTokens] como extensión y deriva el `ColorScheme`, la tipografía y los
/// estilos base de los widgets Material, de modo que incluso las pantallas que
/// no usan los componentes propios se re-estilizan al cambiar los tokens.
class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onDanger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSoft,
      primaryContainer: c.surfaceSoft,
      onPrimaryContainer: c.ink,
      secondaryContainer: c.surfaceSoft,
      onSecondaryContainer: c.ink,
      surfaceContainerHighest: c.surfaceSoft,
      outline: c.line,
      outlineVariant: c.line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: AppType.fontFamily,
      textTheme: AppType.textTheme(c.ink),
      extensions: [AppTokens(c)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        titleTextStyle: AppType.titleL.copyWith(color: c.ink),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.ink),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: AppType.body.copyWith(color: c.surface, fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppType.titleM.copyWith(color: c.ink),
        contentTextStyle: AppType.body.copyWith(color: c.inkSoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      // Botones Material heredan colores/acento; los propios (AppButton) dan
      // control fino. Se mantienen coherentes con los tokens.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size.fromHeight(56),
          textStyle: AppType.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: AppType.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSoft,
        hintStyle: AppType.body.copyWith(color: c.inkFaint),
        labelStyle: AppType.body.copyWith(color: c.inkSoft),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSoft,
        labelStyle: AppType.caption.copyWith(color: c.ink),
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    );
  }
}
