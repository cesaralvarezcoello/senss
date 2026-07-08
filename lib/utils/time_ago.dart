import 'package:intl/intl.dart';

/// Frases de "línea de tiempo del recuerdo": cuánto tiempo ha pasado desde que
/// se grabó una audiografía. El valor emocional crece con el tiempo.
class TimeAgo {
  /// Ej. "Hoy", "Hace 3 días", "Hace 2 meses", "Hace 1 año".
  static String short(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays <= 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';

    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? 'mes' : 'meses'}';
    }
    final years = (diff.inDays / 365).floor();
    return 'Hace $years ${years == 1 ? 'año' : 'años'}';
  }

  /// Ej. "Hace 1 año, Carlos dijo…" — resalta el valor del recuerdo.
  static String sentence(DateTime date, String author) {
    return '${short(date)}, $author dijo…';
  }

  /// Fecha absoluta legible, ej. "8 de julio de 2026".
  static String fullDate(DateTime date) {
    return DateFormat("d 'de' MMMM 'de' y", 'es').format(date);
  }
}
