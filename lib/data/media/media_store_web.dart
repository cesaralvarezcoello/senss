import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:uuid/uuid.dart';

import 'media_store.dart';

MediaStore createMediaStore() => WebMediaStore();

/// Backend del navegador: los bytes de fotos/audios se guardan en IndexedDB.
/// La referencia es una clave `m:...`. Nada sale del navegador.
class WebMediaStore implements MediaStore {
  static const _uuid = Uuid();
  static const _dbName = 'senss_media';
  static const _store = 'media';

  Database? _db;

  @override
  String get label => 'Este navegador';

  Future<Database> _open() async {
    return _db ??= await idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_store)) {
          db.createObjectStore(_store);
        }
      },
    );
  }

  Future<String> _put(Uint8List bytes, String kind, String ext) async {
    final db = await _open();
    final key = 'm:$kind:${_uuid.v4()}.$ext';
    final txn = db.transaction(_store, idbModeReadWrite);
    await txn.objectStore(_store).put(bytes, key);
    await txn.completed;
    return key;
  }

  @override
  Future<String> savePhoto(Uint8List bytes, {String ext = 'jpg'}) =>
      _put(bytes, 'p', ext);

  @override
  Future<String> saveAudio(Uint8List bytes, {String ext = 'm4a'}) =>
      _put(bytes, 'a', ext);

  @override
  Future<Uint8List?> readBytes(String ref) async {
    final db = await _open();
    final txn = db.transaction(_store, idbModeReadOnly);
    final v = await txn.objectStore(_store).getObject(ref);
    await txn.completed;
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return null;
  }

  @override
  Future<void> delete(String ref) async {
    final db = await _open();
    final txn = db.transaction(_store, idbModeReadWrite);
    await txn.objectStore(_store).delete(ref);
    await txn.completed;
  }

  @override
  Future<ImageProvider> imageProvider(String ref) async {
    final bytes = await readBytes(ref);
    return MemoryImage(bytes ?? Uint8List(0));
  }

  @override
  Future<Uri?> audioUri(String ref) async {
    final bytes = await readBytes(ref);
    if (bytes == null) return null;
    final ext = ref.contains('.') ? ref.split('.').last.toLowerCase() : 'm4a';
    final mime = switch (ext) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'ogg' => 'audio/ogg',
      _ => 'audio/mp4',
    };
    // data: URI reproducible por just_audio en la web.
    return Uri.dataFromBytes(bytes, mimeType: mime);
  }

  @override
  Future<String?> newRecordingPath() async => null; // grabación web aparte
}
