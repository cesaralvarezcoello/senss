import 'package:flutter/material.dart';

/// Estilo visual (color + emoji) de cada emoción, para dar calidez a las
/// audiografías: el anillo de la burbuja toma este color y la etiqueta muestra
/// el emoji. Ver [AppConstants.emotionTags].
class EmotionStyle {
  final Color color;
  final String emoji;
  const EmotionStyle(this.color, this.emoji);

  static const _map = <String, EmotionStyle>{
    'Alegría': EmotionStyle(Color(0xFFF5A524), '☀️'),
    'Amor': EmotionStyle(Color(0xFFE5484D), '❤️'),
    'Gratitud': EmotionStyle(Color(0xFF30A46C), '🙏'),
    'Nostalgia': EmotionStyle(Color(0xFF8E4EC6), '🍂'),
    'Ternura': EmotionStyle(Color(0xFFE93D82), '🌸'),
    'Orgullo': EmotionStyle(Color(0xFFF76B15), '⭐'),
    'Esperanza': EmotionStyle(Color(0xFF12A594), '🌱'),
    'Paz': EmotionStyle(Color(0xFF3E63DD), '🕊️'),
  };

  /// Estilo por defecto cuando no hay emoción asignada.
  static const fallback = EmotionStyle(Color(0xFF6E56CF), '💬');

  static EmotionStyle of(String? tag) => _map[tag] ?? fallback;
}
