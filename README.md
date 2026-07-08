# senss

Audiografías privadas y locales para preservar recuerdos — una app de apoyo,
sin fines de lucro, para personas con Alzheimer.

Cada **recuerdo** es una foto. A cada foto se le adjuntan **audiografías**:
notas de audio de familiares y amigos que se acumulan con el tiempo, formando
un hilo de audio-recuerdos. **Todo se guarda únicamente en el dispositivo.**

---

## 1. Requisitos

Flutter **no está instalado** en esta máquina todavía. Instálalo primero:

- Guía oficial (Windows): <https://docs.flutter.dev/get-started/install/windows>
- Verifica con:
  ```bash
  flutter --version
  flutter doctor
  ```

## 2. Generar las carpetas nativas SIN borrar este código

Este repo ya contiene `lib/` y `pubspec.yaml`. Para no sobrescribirlos, genera
las carpetas `android/` e `ios/` en un proyecto temporal y muévelas aquí:

```bash
# Desde la carpeta senss/
flutter create --project-name senss --org com.senss --platforms=android,ios _scaffold
mv _scaffold/android _scaffold/ios .
rm -rf _scaffold

flutter pub get
```

> En Windows PowerShell usa `Move-Item _scaffold\android .` , `Move-Item _scaffold\ios .` y `Remove-Item -Recurse -Force _scaffold`.

## 3. Ejecutar

```bash
flutter run
```

---

## 4. Permisos nativos (obligatorio)

Después de generar las carpetas nativas, añade los permisos de micrófono,
cámara y galería. (La CI de GitHub Actions inyecta los de Android
automáticamente en su build; esto es para tu entorno local.)

**Android** — `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** — `ios/Runner/Info.plist`, dentro de `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>senss usa el micrófono para grabar audiografías de tus recuerdos.</string>
<key>NSCameraUsageDescription</key>
<string>senss usa la cámara para tomar fotos de tus recuerdos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>senss accede a tus fotos para crear recuerdos.</string>
```

---

## 5. Estructura del proyecto

```
lib/
├─ main.dart                     # Punto de entrada; inicializa Provider e i18n
├─ app.dart                      # MaterialApp + tema
├─ core/
│  ├─ constants.dart             # Nombre, etiquetas de emociones, términos
│  └─ theme.dart                 # Tema accesible (fuentes grandes, alto contraste)
├─ data/
│  ├─ models/
│  │  ├─ memory.dart             # Modelo Memory (foto, título, fecha)
│  │  └─ audiography.dart        # Modelo Audiography (audio, autor, emoción, fecha)
│  ├─ database/
│  │  └─ app_database.dart       # SQLite local (sqflite) + esquema
│  ├─ repositories/
│  │  └─ memory_repository.dart  # CRUD y consultas del feed
│  └─ services/
│     ├─ storage_service.dart    # Guarda fotos/audios como archivos privados
│     ├─ audio_recorder_service.dart  # Grabación AAC/.m4a (record)
│     ├─ audio_player_service.dart    # Reproducción individual/secuencial (just_audio)
│     ├─ backup_service.dart          # Copia de seguridad cifrada (AES-256-GCM + PBKDF2)
│     └─ moderation_service.dart      # Interfaz de moderación + variante permisiva (por defecto)
├─ state/
│  └─ memory_provider.dart       # Estado central (ChangeNotifier)
├─ utils/
│  └─ time_ago.dart              # "Hace 1 año, Carlos dijo…"
└─ features/
   ├─ feed/                      # Pantalla de inicio (feed estilo Instagram)
   ├─ create/                    # Crear recuerdo (tomar/importar foto)
   ├─ record/                    # Grabar / editar audiografía (hoja inferior)
   └─ backup/                    # Exportar/importar copia de seguridad cifrada
```

## 6. Arquitectura y privacidad

- **100% local.** Metadatos en SQLite (`sqflite`); fotos y audios como archivos
  en `getApplicationDocumentsDirectory()`. Ningún servidor externo.
- **Audio comprimido** en AAC (`.m4a`, 64 kbps mono) para no saturar el disco.
- **Relación 1‑a‑N:** un `Memory` tiene muchas `Audiography` (`ON DELETE CASCADE`).

## 7. Seguridad y moderación

`ModerationService.reviewImage()` se ejecuta **antes** de guardar cualquier
foto. Si una implementación marca la foto como no apta, `createMemory` lanza
`ModerationException` y la pantalla de creación muestra el motivo; nada se
guarda.

El servicio por defecto es `PermissiveModerationService` (aprueba todo), que
deja el punto de integración listo.

**Moderación real on-device (add-on opcional).** Existe
`NsfwModerationService`: un clasificador **NSFW en TensorFlow Lite** que decide
seguro/no-seguro sobre los píxeles, 100% en el dispositivo, con degradación
segura si falta el modelo. Está **desacoplado del build por defecto** porque
`tflite_flutter` 0.11.0 es incompatible con AGP 8 (namespace duplicado de los
AAR de TensorFlow Lite). El código, sus tests y las instrucciones para
habilitarlo viven en `optional/nsfw_moderation/` (ver su `README.md`).

Para el audio: términos de uso claros antes de grabar (`AppConstants
.audioTermsShort`) y categorización con etiquetas de emociones positivas.

## 8. Copia de seguridad local cifrada

Desde la pantalla principal, el icono de escudo abre **Copia de seguridad**
(`lib/features/backup/`). Permite exportar todos los recuerdos y audiografías
a un único archivo `.senssbak` **cifrado con contraseña**, y restaurarlo.

- **Formato:** un ZIP (`manifest.json` con los metadatos en JSON + las fotos y
  audios en `media/`) cifrado con **AES-256-GCM**. La clave se deriva de la
  contraseña con **PBKDF2-HMAC-SHA256** (120 000 iteraciones). Estructura del
  archivo: `"SENSSBK1" | salt(16) | nonce(12) | ciphertext | mac(16)`.
- **Privacidad:** el archivo se genera en el dispositivo; el usuario elige dónde
  guardarlo (`file_picker`). Ningún servidor interviene.
- **Restaurar = fusionar:** los elementos se insertan/actualizan por `id`, así
  que restaurar dos veces es seguro y nunca borra datos existentes. Como las
  rutas de archivo son absolutas y cambian entre instalaciones, al importar se
  reescriben al almacenamiento del dispositivo actual.
- Toda la lógica reutilizable vive en `BackupService`; la UI solo elige archivos
  y contraseñas. `cryptography` es puro Dart — para acelerarlo con las APIs
  nativas del sistema puedes añadir `cryptography_flutter`.

## 9. Próximos pasos sugeridos

- ✅ Rastrear qué audiografía está sonando (resaltar la fila activa).
- ✅ Barra de progreso/scrubber en la reproducción.
- ✅ Editar/eliminar audiografías individuales.
- ✅ Copia de seguridad local cifrada (exportar/importar).
- ✅ Moderación real on-device (add-on en `optional/nsfw_moderation/`; ver §7).
  Pendiente: compatibilidad de `tflite_flutter` con AGP 8 para integrarla por
  defecto.

## 10. Integración continua (CI)

`.github/workflows/ci.yml` corre en cada push/PR (y a mano desde **Actions**):

- **test** — `flutter pub get` (publica `pubspec.lock` como artefacto), `flutter
  analyze` (informativo) y `flutter test`.
- **build-android** — genera `android/` (README §2), inyecta los permisos
  (README §4) y compila `app-debug.apk` (artefacto `app-debug-apk`).
- **build-android-release** — igual, pero produce **release firmado** en dos
  formatos: un **APK** (`app-release-signed-apk`, para instalar/sideload) y un
  **App Bundle `.aab`** (`app-release-signed-aab`, para subir a Google Play).
  Solo se ejecuta si hay keystore en Secrets. Como `android/` se genera al vuelo
  (y su Gradle puede ser Groovy o Kotlin), no se editan ficheros Gradle: se
  compila el release y se firma el APK con `apksigner` (+`zipalign`) y el `.aab`
  con `jarsigner` (firma JAR que espera la clave de subida de Play). Además,
  `bundletool` valida el `.aab` generando un APK universal instalable
  (artefacto `app-release-universal-apk`).

### Firmar el APK de release

1. Genera un keystore (una vez):
   ```bash
   keytool -genkey -v -keystore senss-release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias senss
   ```
2. Conviértelo a base64 en una sola línea:
   ```bash
   base64 -w0 senss-release.jks > senss-release.jks.b64   # Linux
   # macOS: base64 -i senss-release.jks -o senss-release.jks.b64
   ```
3. En GitHub: **Settings → Secrets and variables → Actions → New repository
   secret**, y crea:
   - `ANDROID_KEYSTORE_BASE64` — contenido de `senss-release.jks.b64`
   - `ANDROID_KEYSTORE_PASSWORD` — contraseña del almacén
   - `ANDROID_KEY_PASSWORD` — contraseña de la clave (a menudo la misma)
   - `ANDROID_KEY_ALIAS` — el alias (`senss` en el ejemplo)

El APK firmado queda como artefacto `app-release-signed-apk`. **Guarda el
keystore y las contraseñas de forma segura:** para actualizar la app en Google
Play debes firmar siempre con el mismo keystore.
