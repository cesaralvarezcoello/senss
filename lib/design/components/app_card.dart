import 'package:flutter/material.dart';

import '../tokens.dart';

/// Contenedor elevado estándar: superficie, radio y sombra desde los tokens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final bool clip;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.xl,
    this.onTap,
    this.clip = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: c.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
