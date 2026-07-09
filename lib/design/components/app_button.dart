import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Estilo del botón. `glass` = cristal esmerilado (sobre fotos). Cambiar de
/// sólido a cristal es solo cambiar este parámetro — todo centralizado.
enum AppButtonVariant { primary, tonal, ghost, danger, glass }

enum AppButtonSize { large, medium }

/// Botón único de la app. Grande y de alto contraste (accesible). Su apariencia
/// se deriva de los tokens: recolorear un token re-estiliza todos los botones.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool busy;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.expand = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    final glass = variant == AppButtonVariant.glass;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (c.accent, c.onAccent, null),
      AppButtonVariant.tonal => (c.surfaceSoft, c.ink, null),
      AppButtonVariant.ghost => (Colors.transparent, c.accent, c.line),
      AppButtonVariant.danger => (c.danger, c.onDanger, null),
      AppButtonVariant.glass => (
          Colors.white.withValues(alpha: 0.16),
          Colors.white,
          Colors.white.withValues(alpha: 0.30),
        ),
    };

    final height = size == AppButtonSize.large ? 58.0 : 48.0;
    final radius = AppRadius.lg;

    final content = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: AppSpace.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: fg),
                ),
              ),
            ],
          );

    final inner = InkWell(
      onTap: enabled ? onPressed : null,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: glass ? bg : null,
          border: border == null
              ? null
              : Border.all(color: border, width: 1.5),
        ),
        child: content,
      ),
    );

    final material = Material(
      color: glass ? Colors.transparent : bg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );

    final Widget button = glass
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: material,
            ),
          )
        : material;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: height,
        child: button,
      ),
    );
  }
}
