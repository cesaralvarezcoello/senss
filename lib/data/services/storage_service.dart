import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Gestiona los archivos binarios (fotos y audios) dentro del almacenamiento
/// privado de la app. Nada sale del dispositivo.
class StorageService {
  static const _uuid = Uuid();

  Future<Directory> _subdir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copia una foto (tomada o importada) al almacenamiento privado y devuelve
  /// su nueva ruta permanente. Preserva la extensión original.
  Future<String> savePhoto(String sourcePath) async {
    final dir = await _subdir('photos');
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Devuelve una ruta nueva y única para grabar un audio (.m4a).
  Future<String> newAudioPath() async {
    final dir = await _subdir('audios');
    return p.join(dir.path, '${_uuid.v4()}.m4a');
  }

  /// Escribe los bytes de una foto restaurada (desde una copia de seguridad)
  /// conservando su nombre de archivo, y devuelve la nueva ruta absoluta en
  /// este dispositivo.
  Future<String> writePhotoBytes(String fileName, List<int> bytes) async {
    final dir = await _subdir('photos');
    final dest = p.join(dir.path, fileName);
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  /// Igual que [writePhotoBytes] pero para un audio restaurado.
  Future<String> writeAudioBytes(String fileName, List<int> bytes) async {
    final dir = await _subdir('audios');
    final dest = p.join(dir.path, fileName);
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
