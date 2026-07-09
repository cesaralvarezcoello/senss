import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Panel de cristal esmerilado (glassmorphism): desenfoca lo que hay detrás y
/// aplica un tinte translúcido. Se usa sobre la foto para sostener texto sin
/// taparla. El [tint] suele derivarse del color dinámico de la foto.
class AppGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final Color? borderColor;

  const AppGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.lg,
    this.blur = 18,
    this.tint,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
