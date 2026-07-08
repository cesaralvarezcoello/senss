import 'dart:io';

/// Resultado de una revisión de moderación local.
class ModerationResult {
  final bool allowed;
  final String? reason;
  const ModerationResult.allowed()
      : allowed = true,
        reason = null;
  const ModerationResult.blocked(this.reason) : allowed = false;
}

/// Capa de moderación de contenido que se ejecuta ANTES de guardar cualquier
/// archivo, para mantener senss como un entorno de "lindos sentimientos"
/// libre de violencia o pornografía.
///
/// Toda la validación ocurre en el dispositivo; ningún dato sale de él.
abstract class ModerationService {
  Future<ModerationResult> reviewImage(File image);
}

/// Implementación que **permite todo** el contenido. Es la alternativa explícita
/// para desactivar la moderación (p. ej. en pruebas). La detección real
/// on-device la aporta `NsfwModerationService` (clasificador NSFW en TensorFlow
/// Lite), que es el servicio por defecto de la app.
///
/// Ver README > Seguridad y moderación.
class PermissiveModerationService implements ModerationService {
  @override
  Future<ModerationResult> reviewImage(File image) async {
    return const ModerationResult.allowed();
  }
}
