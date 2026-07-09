import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../media/media_store.dart';
import '../models/audiography.dart';
import '../models/memory.dart';
import '../repositories/memory_repository.dart';

/// Error legible durante exportación/importación de copias de seguridad.
class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Cuántos elementos contiene (o restauró) una copia.
class BackupStats {
  final int memories;
  final int audiographies;
  const BackupStats({required this.memories, required this.audiographies});
}

/// Crea y restaura copias de seguridad **locales y cifradas** de todos los
/// recuerdos y audiografías.
///
/// Formato del archivo `.senssbak` (todo binario):
/// ```
/// [ "SENSSBK1" (8) ][ salt (16) ][ nonce (12) ][ ciphertext (N) ][ mac (16) ]
/// ```
/// El *ciphertext* es un ZIP (`manifest.json` + `media/photos/…` +
/// `media/audios/…`) cifrado con **AES-256-GCM**. La clave se deriva de la
/// contraseña del usuario con **PBKDF2-HMAC-SHA256**. Nada sale del dispositivo:
/// el usuario decide dónde guardar el archivo resultante.
class BackupService {
  final MemoryRepository _repo;

  BackupService({MemoryRepository? repository})
      : _repo = repository ?? MemoryRepository();

  static const _magic = 'SENSSBK1'; // 8 bytes
  static const _formatVersion = 1;
  static const _pbkdf2Iterations = 120000;

  static const _saltLen = 16;
  static const _nonceLen = 12; // por defecto en AES-GCM
  static const _macLen = 16;

  final AesGcm _aes = AesGcm.with256bits();

  // ---------------------------------------------------------------------------
  // Exportar
  // ---------------------------------------------------------------------------

  /// Empaqueta todo y devuelve los bytes cifrados listos para guardar, junto
  /// con un resumen de lo incluido.
  Future<(Uint8List, BackupStats)> exportEncrypted(String password) async {
    if (password.isEmpty) {
      throw BackupException('La contraseña no puede estar vacía.');
    }

    final feed = await _repo.getFeed();
    final archive = Archive();
    final memoriesJson = <Map<String, Object?>>[];
    final audiosJson = <Map<String, Object?>>[];
    var audioCount = 0;

    for (final item in feed) {
      final memory = item.memory;
      final photoName = '${memory.id}${p.extension(memory.photoPath)}';
      final photoBytes = await Media.store.readBytes(memory.photoPath);
      if (photoBytes != null) {
        archive.addFile(
          ArchiveFile('media/photos/$photoName', photoBytes.length, photoBytes),
        );
      }
      memoriesJson.add({
        'id': memory.id,
        'photo_file': photoName,
        'title': memory.title,
        'description': memory.description,
        'created_at': memory.createdAt.millisecondsSinceEpoch,
      });

      for (final a in item.audios) {
        final audioName = '${a.id}${p.extension(a.audioPath)}';
        final audioBytes = await Media.store.readBytes(a.audioPath);
        if (audioBytes != null) {
          archive.addFile(
            ArchiveFile('media/audios/$audioName', audioBytes.length, audioBytes),
          );
        }
        audiosJson.add({
          'id': a.id,
          'memory_id': a.memoryId,
          'audio_file': audioName,
          'author_name': a.authorName,
          'emotion_tag': a.emotionTag,
          'duration_ms': a.durationMs,
          'created_at': a.createdAt.millisecondsSinceEpoch,
        });
        audioCount++;
      }
    }

    final manifest = <String, Object?>{
      'format': 'senss-backup',
      'version': _formatVersion,
      'memories': memoriesJson,
      'audiographies': audiosJson,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw BackupException('No se pudo empaquetar la copia de seguridad.');
    }

    final encrypted = await _encrypt(Uint8List.fromList(zipBytes), password);
    final stats = BackupStats(
      memories: memoriesJson.length,
      audiographies: audioCount,
    );
    return (encrypted, stats);
  }

  Future<Uint8List> _encrypt(Uint8List plain, String password) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(_saltLen, (_) => rnd.nextInt(256));
    final key = await _deriveKey(password, salt);
    final nonce = _aes.newNonce(); // 12 bytes
    final box = await _aes.encrypt(plain, secretKey: key, nonce: nonce);

    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(salt);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  // ---------------------------------------------------------------------------
  // Importar
  // ---------------------------------------------------------------------------

  /// Descifra y restaura una copia. Los elementos se **fusionan** por id (los
  /// existentes se actualizan), por lo que restaurar dos veces es seguro.
  /// Devuelve cuántos elementos se restauraron.
  Future<BackupStats> importEncrypted(
      Uint8List fileBytes, String password) async {
    final zipBytes = await _decrypt(fileBytes, password);

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw BackupException('El archivo de copia está dañado.');
    }

    ArchiveFile? manifestFile;
    final media = <String, List<int>>{};
    for (final f in archive) {
      if (!f.isFile) continue;
      if (f.name == 'manifest.json') {
        manifestFile = f;
      } else if (f.name.startsWith('media/')) {
        media[f.name] = f.content as List<int>;
      }
    }
    if (manifestFile == null) {
      throw BackupException('La copia no contiene datos reconocibles.');
    }

    final Map<String, Object?> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, Object?>;
    } catch (_) {
      throw BackupException('La copia no contiene datos reconocibles.');
    }
    if (manifest['format'] != 'senss-backup') {
      throw BackupException('Formato de copia no reconocido.');
    }

    final memories = (manifest['memories'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final audios = (manifest['audiographies'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    // Los recuerdos primero: las audiografías dependen de ellos (clave foránea).
    for (final m in memories) {
      final photoName = m['photo_file'] as String?;
      var photoPath = '';
      if (photoName != null) {
        final bytes = media['media/photos/$photoName'];
        if (bytes != null) {
          final ext = p.extension(photoName).replaceFirst('.', '');
          photoPath = await Media.store
              .savePhoto(Uint8List.fromList(bytes), ext: ext.isEmpty ? 'jpg' : ext);
        }
      }
      await _repo.insertMemory(Memory(
        id: m['id'] as String,
        photoPath: photoPath,
        title: m['title'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      ));
    }

    for (final a in audios) {
      final audioName = a['audio_file'] as String?;
      var audioPath = '';
      if (audioName != null) {
        final bytes = media['media/audios/$audioName'];
        if (bytes != null) {
          final ext = p.extension(audioName).replaceFirst('.', '');
          audioPath = await Media.store
              .saveAudio(Uint8List.fromList(bytes), ext: ext.isEmpty ? 'm4a' : ext);
        }
      }
      await _repo.insertAudiography(Audiography(
        id: a['id'] as String,
        memoryId: a['memory_id'] as String,
        audioPath: audioPath,
        authorName: a['author_name'] as String,
        emotionTag: a['emotion_tag'] as String?,
        durationMs: a['duration_ms'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(a['created_at'] as int),
      ));
    }

    return BackupStats(memories: memories.length, audiographies: audios.length);
  }

  Future<Uint8List> _decrypt(Uint8List bytes, String password) async {
    final magicBytes = utf8.encode(_magic);
    final headerLen = magicBytes.length + _saltLen + _nonceLen;
    if (bytes.length < headerLen + _macLen) {
      throw BackupException('El archivo no es una copia de senss válida.');
    }
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw BackupException('El archivo no es una copia de senss válida.');
      }
    }

    var o = magicBytes.length;
    final salt = bytes.sublist(o, o + _saltLen);
    o += _saltLen;
    final nonce = bytes.sublist(o, o + _nonceLen);
    o += _nonceLen;
    final cipherText = bytes.sublist(o, bytes.length - _macLen);
    final mac = bytes.sublist(bytes.length - _macLen);

    final key = await _deriveKey(password, salt);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    try {
      final clear = await _aes.decrypt(box, secretKey: key);
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw BackupException('Contraseña incorrecta o archivo alterado.');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}
