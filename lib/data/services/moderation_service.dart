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

/// Implementación **por defecto**: permite todo el contenido y deja el punto de
/// integración listo. La detección real on-device es un add-on opcional,
/// `NsfwModerationService` (clasificador NSFW en TensorFlow Lite), que vive en
/// `optional/nsfw_moderation/` desacoplado del build por una incompatibilidad
/// de `tflite_flutter` con AGP 8.
///
/// Ver README > Seguridad y moderación y `optional/nsfw_moderation/README.md`.
class PermissiveModerationService implements ModerationService {
  @override
  Future<ModerationResult> reviewImage(File image) async {
    return const ModerationResult.allowed();
  }
}
