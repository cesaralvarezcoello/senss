import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

enum AppButtonVariant { primary, tonal, ghost, danger }

enum AppButtonSize { large, medium }

/// Botón único de la app. Grande y de alto contraste (accesible para adultos
/// mayores). Su apariencia se deriva de los tokens: recolorear un token
/// re-estiliza todos los botones.
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

    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (c.accent, c.onAccent, null),
      AppButtonVariant.tonal => (c.surfaceSoft, c.ink, null),
      AppButtonVariant.ghost => (Colors.transparent, c.accent, c.line),
      AppButtonVariant.danger => (c.danger, c.onDanger, null),
    };

    final height = size == AppButtonSize.large ? 58.0 : 48.0;
    final radius = AppRadius.lg;

    Widget content = busy
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

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: height,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              decoration: border == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: border, width: 1.5),
                    ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
