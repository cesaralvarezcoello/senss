import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'media_store.dart';

MediaStore createMediaStore() => IoMediaStore();

/// Backend de archivos locales (Android/iOS/desktop). La referencia es la ruta
/// absoluta del archivo, así que es compatible con los datos ya guardados.
class IoMediaStore implements MediaStore {
  static const _uuid = Uuid();

  @override
  String get label => 'Este dispositivo';

  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> savePhoto(Uint8List bytes, {String ext = 'jpg'}) async {
    final dir = await _dir('photos');
    final path = p.join(dir.path, '${_uuid.v4()}.$ext');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Future<String> saveAudio(Uint8List bytes, {String ext = 'm4a'}) async {
    final dir = await _dir('audios');
    final path = p.join(dir.path, '${_uuid.v4()}.$ext');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Future<Uint8List?> readBytes(String ref) async {
    final f = File(ref);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String ref) async {
    final f = File(ref);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<ImageProvider> imageProvider(String ref) async => FileImage(File(ref));

  @override
  Future<Uri?> audioUri(String ref) async => Uri.file(ref);

  @override
  Future<String?> newRecordingPath() async {
    final dir = await _dir('audios');
    return p.join(dir.path, '${_uuid.v4()}.m4a');
  }
}
