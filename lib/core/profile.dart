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

  /// Si ya se vio la bienvenida (onboarding).
  final bool onboarded;

  /// Si la persona que usará senss tiene Alzheimer / problemas de memoria.
  /// Cuando es cierto, la app se vuelve lo más simple posible: todo más grande,
  /// menos opciones en los juegos y prioridad al modo conversación.
  final bool memorySupport;

  const Profile({
    this.name = '',
    this.age = AgeGroup.adult,
    this.gender = Gender.unspecified,
    this.configured = false,
    this.onboarded = false,
    this.memorySupport = false,
  });

  bool get isSenior => age == AgeGroup.senior;
  bool get isYoung => age == AgeGroup.young;

  /// ¿Debe la app ir al máximo de simplicidad? (memoria frágil o tercera edad).
  bool get needsSimplest => memorySupport;

  /// Escala global de texto: la tercera edad ve todo bastante más grande; con
  /// apoyo de memoria, nunca por debajo de 1.3.
  double get textScale {
    final base = switch (age) {
      AgeGroup.senior => 1.35,
      AgeGroup.adult => 1.0,
      AgeGroup.young => 0.92,
    };
    return memorySupport && base < 1.3 ? 1.3 : base;
  }

  /// Tamaño base de iconos y objetivos táctiles.
  double get iconScale => (isSenior || memorySupport) ? 1.2 : 1.0;

  /// Nº de opciones en los juegos: con memoria frágil o tercera edad, menos (2).
  int get choiceCount => (isSenior || memorySupport) ? 2 : 3;

  /// Elige la variante según género (masculino / femenino / neutro).
  String gendered(String m, String f, String n) => switch (gender) {
        Gender.male => m,
        Gender.female => f,
        Gender.unspecified => n,
      };

  Profile copyWith(
          {String? name,
          AgeGroup? age,
          Gender? gender,
          bool? configured,
          bool? onboarded,
          bool? memorySupport}) =>
      Profile(
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        configured: configured ?? this.configured,
        onboarded: onboarded ?? this.onboarded,
        memorySupport: memorySupport ?? this.memorySupport,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'age': age.index,
        'gender': gender.index,
        'configured': configured,
        'onboarded': onboarded,
        'memory_support': memorySupport,
      };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
        name: j['name'] as String? ?? '',
        age: AgeGroup.values[(j['age'] as int?) ?? AgeGroup.adult.index],
        gender: Gender.values[(j['gender'] as int?) ?? Gender.unspecified.index],
        configured: j['configured'] as bool? ?? false,
        onboarded: j['onboarded'] as bool? ?? false,
        memorySupport: j['memory_support'] as bool? ?? false,
      );
}
