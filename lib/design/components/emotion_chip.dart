import 'package:flutter/material.dart';

import '../../core/emotions.dart';
import '../tokens.dart';
import '../typography.dart';

/// Etiqueta de emoción: emoji + nombre, teñida con el color de la emoción.
class EmotionChip extends StatelessWidget {
  final String label;
  final bool compact;

  const EmotionChip({super.key, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = EmotionStyle.of(label);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(style.emoji, style: TextStyle(fontSize: compact ? 12 : 14)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.caption.copyWith(
              fontSize: compact ? 12.5 : 14,
              fontWeight: FontWeight.w700,
              color: _readable(style.color),
            ),
          ),
        ],
      ),
    );
  }

  // Oscurece el color de la emoción para que el texto tenga buen contraste.
  Color _readable(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
  }
}
