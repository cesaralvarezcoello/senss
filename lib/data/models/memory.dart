/// Un "recuerdo": una foto propiedad del usuario a la que se le adjuntan
/// audiografías (notas de audio) con el paso del tiempo.
class Memory {
  final String id;

  /// Ruta absoluta a la foto dentro del almacenamiento privado de la app.
  final String photoPath;

  /// Título corto y legible del recuerdo (ej. "Verano en la playa").
  final String title;

  /// Descripción opcional más larga.
  final String? description;

  final DateTime createdAt;

  const Memory({
    required this.id,
    required this.photoPath,
    required this.title,
    this.description,
    required this.createdAt,
  });

  static const table = 'memories';

  factory Memory.fromMap(Map<String, Object?> map) => Memory(
        id: map['id'] as String,
        photoPath: map['photo_path'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'photo_path': photoPath,
        'title': title,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Memory copyWith({
    String? title,
    String? description,
    String? photoPath,
  }) =>
      Memory(
        id: id,
        photoPath: photoPath ?? this.photoPath,
        title: title ?? this.title,
        description: description ?? this.description,
        createdAt: createdAt,
      );
}
