import 'profile.dart';

/// Copy **centralizado y adaptativo**: cada texto se elige según el perfil
/// (edad y género). Es el único lugar donde vive el copy de la app, así que
/// cambiar tono o idioma es cambiar aquí. Preparado para multiidioma
/// (añadiendo un `Locale` a las variantes).
class AppCopy {
  final Profile p;
  const AppCopy(this.p);

  String get _name => p.name.trim();

  // ---- Modo paciente (Momento) ----

  String greeting(String timeOfDay) {
    final base = _name.isEmpty ? timeOfDay : '$timeOfDay, $_name';
    return '$base 💛';
  }

  String get momentSubtitle => switch (p.age) {
        AgeGroup.senior => 'Alguien que te quiere pensó en ti',
        AgeGroup.adult => 'Un momento de quienes te quieren',
        AgeGroup.young => 'Un recuerdo tuyo para revivir',
      };

  String playHint(String speaker) {
    if (speaker.isEmpty) return 'Toca y escucha';
    return p.isSenior ? 'Toca para oír a $speaker' : 'Toca y escucha a $speaker';
  }

  String nowPlaying(String speaker) => 'La voz de $speaker, contigo';

  String get noVoices => 'Este recuerdo todavía espera una voz 💛';

  String get emptyTitle =>
      p.isYoung ? 'Tus recuerdos empiezan aquí' : 'Aquí vivirán tus recuerdos';

  String get emptyBody => switch (p.age) {
        AgeGroup.senior =>
          'Tu familia irá guardando las fotos y las voces de quienes te '
              'quieren, para acompañarte.',
        _ => 'Guarda tus fotos y grábales las voces de quienes te importan.',
      };

  String get otherMemory => 'Otro recuerdo';

  // ---- Actividades ("Juega con tus recuerdos") ----

  String get playTitle =>
      p.isSenior ? 'Juega con tus recuerdos' : 'Juega con tus recuerdos';

  /// Bienvenida con concordancia de género.
  String get welcome => p.gendered('Bienvenido', 'Bienvenida', 'Te damos la bienvenida');
}
