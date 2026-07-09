/// Perfil de la persona que usa senss. Impulsa la adaptación **centralizada**
/// de textos, tamaños e iconos según edad y género.
enum AgeGroup { young, adult, senior }

enum Gender { male, female, unspecified }

class Profile {
  final String name;
  final AgeGroup age;
  final Gender gender;

  /// Si la familia ya configuró el perfil (para no volver a preguntar).
  final bool configured;

  const Profile({
    this.name = '',
    this.age = AgeGroup.adult,
    this.gender = Gender.unspecified,
    this.configured = false,
  });

  bool get isSenior => age == AgeGroup.senior;
  bool get isYoung => age == AgeGroup.young;

  /// Escala global de texto: la tercera edad ve todo bastante más grande.
  double get textScale => switch (age) {
        AgeGroup.senior => 1.35,
        AgeGroup.adult => 1.0,
        AgeGroup.young => 0.92,
      };

  /// Tamaño base de iconos y objetivos táctiles.
  double get iconScale => isSenior ? 1.2 : 1.0;

  /// Elige la variante según género (masculino / femenino / neutro).
  String gendered(String m, String f, String n) => switch (gender) {
        Gender.male => m,
        Gender.female => f,
        Gender.unspecified => n,
      };

  Profile copyWith({String? name, AgeGroup? age, Gender? gender, bool? configured}) =>
      Profile(
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        configured: configured ?? this.configured,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'age': age.index,
        'gender': gender.index,
        'configured': configured,
      };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        name: j['name'] as String? ?? '',
        age: AgeGroup.values[(j['age'] as int?) ?? AgeGroup.adult.index],
        gender: Gender.values[(j['gender'] as int?) ?? Gender.unspecified.index],
        configured: j['configured'] as bool? ?? false,
      );
}
