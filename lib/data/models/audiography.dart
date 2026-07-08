/// Una "audiografía": una nota de audio grabada por una persona y adjunta a
/// un recuerdo (foto). Una foto puede tener muchas audiografías de distintos
/// autores, formando un hilo de audio-recuerdos.
class Audiography {
  final String id;

  /// Id del [Memory] al que pertenece.
  final String memoryId;

  /// Ruta absoluta al archivo de audio (.m4a / AAC) en almacenamiento privado.
  final String audioPath;

  /// Nombre de quien grabó la audiografía (ej. "Carlos, tu hijo").
  final String authorName;

  /// Etiqueta de emoción positiva asociada (ver AppConstants.emotionTags).
  final String? emotionTag;

  /// Duración del audio en milisegundos.
  final int durationMs;

  final DateTime createdAt;

  const Audiography({
    required this.id,
    required this.memoryId,
    required this.audioPath,
    required this.authorName,
    this.emotionTag,
    required this.durationMs,
    required this.createdAt,
  });

  static const table = 'audiographies';

  /// Copia con cambios. [clearEmotion] fuerza `emotionTag` a null (para quitar
  /// la etiqueta), ya que un null en [emotionTag] no distingue "sin cambio".
  Audiography copyWith({
    String? authorName,
    String? emotionTag,
    bool clearEmotion = false,
  }) =>
      Audiography(
        id: id,
        memoryId: memoryId,
        audioPath: audioPath,
        authorName: authorName ?? this.authorName,
        emotionTag: clearEmotion ? null : (emotionTag ?? this.emotionTag),
        durationMs: durationMs,
        createdAt: createdAt,
      );

  factory Audiography.fromMap(Map<String, Object?> map) => Audiography(
        id: map['id'] as String,
        memoryId: map['memory_id'] as String,
        audioPath: map['audio_path'] as String,
        authorName: map['author_name'] as String,
        emotionTag: map['emotion_tag'] as String?,
        durationMs: map['duration_ms'] as int? ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'memory_id': memoryId,
        'audio_path': audioPath,
        'author_name': authorName,
        'emotion_tag': emotionTag,
        'duration_ms': durationMs,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
