import 'dart:typed_data';

import 'package:flutter/widgets.dart';

// Backend por defecto según la plataforma (archivos en nativo, IndexedDB en
// web). El default se elige en tiempo de compilación con importación condicional.
import 'media_store_web.dart' if (dart.library.io) 'media_store_io.dart';

/// Almacenamiento de medios **agnóstico**: la app guarda/lee fotos y audios a
/// través de esta interfaz, sin saber si viven en archivos locales, en el
/// navegador (IndexedDB) o —en el futuro— en una carpeta elegida por el usuario
/// o en la nube. Cada medio se referencia por un [String] opaco (`ref`).
abstract class MediaStore {
  /// Guarda una foto y devuelve su referencia.
  Future<String> savePhoto(Uint8List bytes, {String ext = 'jpg'});

  /// Guarda un audio y devuelve su referencia.
  Future<String> saveAudio(Uint8List bytes, {String ext = 'm4a'});

  /// Bytes de un medio (o null si no existe).
  Future<Uint8List?> readBytes(String ref);

  /// Elimina un medio.
  Future<void> delete(String ref);

  /// Proveedor de imagen para mostrar la foto en un widget / extraer color.
  Future<ImageProvider> imageProvider(String ref);

  /// URI reproducible del audio (para just_audio).
  Future<Uri?> audioUri(String ref);

  /// Ruta donde grabar un audio nuevo, si la plataforma lo permite grabando a
  /// archivo (nativo). En web devuelve null (la grabación se maneja aparte).
  Future<String?> newRecordingPath();

  /// Nombre legible del backend (para ajustes / "dónde se guarda").
  String get label;
}

/// Backend activo. Por defecto, el de la plataforma; se puede reemplazar para
/// que el usuario decida dónde guardar (p. ej. otra carpeta o la nube).
class Media {
  Media._();
  static MediaStore _backend = createMediaStore();

  static MediaStore get store => _backend;

  /// Cambia el backend de almacenamiento en caliente.
  static void use(MediaStore backend) => _backend = backend;
}
