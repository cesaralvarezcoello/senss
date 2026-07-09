import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Variante semántica del texto (mapea a la escala de [AppType]).
enum AppTextVariant { display, titleL, titleM, body, bodyStrong, label, caption, overline }

/// Tono del texto (mapea a un color de la paleta). Centraliza el color: cambiar
/// un token recolorea todos los textos de ese tono.
enum AppTone { ink, soft, faint, accent, onAccent, danger, onPhoto }

/// Único componente de texto de la app. Todo texto debería pasar por aquí para
/// poder controlar tipografía y color de forma centralizada.
class AppText extends StatelessWidget {
  final String data;
  final AppTextVariant variant;
  final AppTone tone;
  final Color? color;
  final int? maxLines;
  final TextAlign? align;
  final double? sizeOverride;

  const AppText(
    this.data, {
    super.key,
    this.variant = AppTextVariant.body,
    this.tone = AppTone.ink,
    this.color,
    this.maxLines,
    this.align,
    this.sizeOverride,
  });

  static TextStyle styleOf(AppTextVariant v) {
    switch (v) {
      case AppTextVariant.display:
        return AppType.display;
      case AppTextVariant.titleL:
        return AppType.titleL;
      case AppTextVariant.titleM:
        return AppType.titleM;
      case AppTextVariant.body:
        return AppType.body;
      case AppTextVariant.bodyStrong:
        return AppType.bodyStrong;
      case AppTextVariant.label:
        return AppType.label;
      case AppTextVariant.caption:
        return AppType.caption;
      case AppTextVariant.overline:
        return AppType.overline;
    }
  }

  Color _toneColor(AppColors c) {
    switch (tone) {
      case AppTone.ink:
        return c.ink;
      case AppTone.soft:
        return c.inkSoft;
      case AppTone.faint:
        return c.inkFaint;
      case AppTone.accent:
        return c.accent;
      case AppTone.onAccent:
        return c.onAccent;
      case AppTone.danger:
        return c.danger;
      case AppTone.onPhoto:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var style = styleOf(variant).copyWith(color: color ?? _toneColor(c));
    if (sizeOverride != null) style = style.copyWith(fontSize: sizeOverride);
    if (tone == AppTone.onPhoto) {
      style = style.copyWith(shadows: const [
        Shadow(color: Color(0x99000000), blurRadius: 12, offset: Offset(0, 1)),
      ]);
    }
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      textAlign: align,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
