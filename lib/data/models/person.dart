/// Una persona querida (hijo, nieta, esposo…): su nombre, relación y un retrato.
/// Habilita los juegos de reconocimiento de caras.
class Person {
  final String id;
  final String name;
  final String relationship; // ej. "tu hijo"
  final String portraitPath; // referencia de medio (puede estar vacía)
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.name,
    this.relationship = '',
    this.portraitPath = '',
    required this.createdAt,
  });

  static const table = 'people';

  bool get hasPortrait => portraitPath.isNotEmpty;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'portrait_path': portraitPath,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Person.fromMap(Map<String, Object?> m) => Person(
        id: m['id'] as String,
        name: m['name'] as String,
        relationship: m['relationship'] as String? ?? '',
        portraitPath: m['portrait_path'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as num).toInt()),
      );
}
