# Add-on: moderación NSFW on-device (opcional)

Clasificador **seguro / no-seguro** en TensorFlow Lite que revisa cada foto en
el dispositivo antes de guardarla. Está **desacoplado del build por defecto**.

## ¿Por qué está fuera de `lib/`?

`tflite_flutter` 0.11.0 es incompatible con Android Gradle Plugin 8: los AAR
oficiales `tensorflow-lite`, `tensorflow-lite-api` y `tensorflow-lite-gpu`
comparten el namespace `org.tensorflow.lite`, y AGP 8 exige namespaces únicos,
por lo que el *merge* del manifest falla. Para no bloquear el build de la app
(y porque el modelo `.tflite` no se incluye, así que la moderación por defecto
ya era un no-op), este código vive aquí y no se compila.

Mientras tanto, la app usa `PermissiveModerationService` (aprueba todo).

## Contenido

- `nsfw_moderation_service.dart` — el servicio (`NsfwModerationService`).
- `nsfw_moderation_service_test.dart` — sus tests unitarios.
- `MODEL.md` — qué modelo `.tflite` colocar y formatos de salida soportados.

## Cómo habilitarlo

1. **Dependencias** — en `pubspec.yaml`, bajo dependencies:
   ```yaml
   tflite_flutter: ">=0.11.0 <0.12.0"
   image: ">=4.1.0 <5.0.0"
   ```
   y declara el asset del modelo:
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```

2. **Código** — mueve los ficheros a sus carpetas compiladas:
   ```bash
   mkdir -p assets/models
   git mv optional/nsfw_moderation/MODEL.md assets/models/README.md
   git mv optional/nsfw_moderation/nsfw_moderation_service.dart lib/data/services/
   git mv optional/nsfw_moderation/nsfw_moderation_service_test.dart test/
   ```

3. **Modelo** — coloca `assets/models/nsfw.tflite` (ver `MODEL.md`).

4. **Provider** — en `lib/state/memory_provider.dart`, importa el servicio y
   ponlo como moderación por defecto:
   ```dart
   import '../data/services/nsfw_moderation_service.dart';
   // ...
   _moderation = moderation ?? NsfwModerationService(),
   ```

5. **Resolver la incompatibilidad de AGP 8** (elige una):
   - Fijar el proyecto Android generado a AGP 7.4.x, o
   - Fijar la versión de Flutter de la CI a una con AGP 7 (p. ej. 3.19.x), o
   - Esperar/usar una versión de `tflite_flutter` que corrija el namespace.

   Sin esto, `flutter build apk` fallará en el *merge* del manifest.

`NsfwModerationService` degrada de forma segura: sin el modelo aprueba todo (o
bloquea si `blockOnUnavailable: true`).
