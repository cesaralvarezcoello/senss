import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/audiography.dart';
import '../data/models/memory.dart';
import '../data/repositories/memory_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/moderation_service.dart';
import '../data/services/nsfw_moderation_service.dart';
import '../data/services/storage_service.dart';

/// Estado central del feed. Orquesta repositorio + almacenamiento de archivos
/// + moderación, y notifica a la UI cuando cambian los recuerdos.
class MemoryProvider extends ChangeNotifier {
  final MemoryRepository _repo;
  final StorageService _storage;
  final ModerationService _moderation;
  final BackupService _backup;
  static const _uuid = Uuid();

  MemoryProvider({
    MemoryRepository? repository,
    StorageService? storage,
    ModerationService? moderation,
    BackupService? backup,
  })  : _repo = repository ?? MemoryRepository(),
        _storage = storage ?? StorageService(),
        _moderation = moderation ?? NsfwModerationService(),
        _backup = backup ??
            BackupService(
              repository: repository ?? MemoryRepository(),
              storage: storage ?? StorageService(),
            );

  List<MemoryWithAudios> _feed = const [];
  List<MemoryWithAudios> get feed => _feed;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadFeed() async {
    _loading = true;
    notifyListeners();
    _feed = await _repo.getFeed();
    _loading = false;
    notifyListeners();
  }

  /// Crea un recuerdo a partir de una foto ya tomada/importada.
  /// Devuelve el recuerdo creado, o lanza [ModerationException] si la imagen
  /// no pasa la moderación local.
  Future<Memory> createMemory({
    required String sourcePhotoPath,
    required String title,
    String? description,
  }) async {
    final review = await _moderation.reviewImage(File(sourcePhotoPath));
    if (!review.allowed) {
      throw ModerationException(review.reason ??
          'La imagen no cumple con las normas del entorno seguro.');
    }

    final storedPath = await _storage.savePhoto(sourcePhotoPath);
    final memory = Memory(
      id: _uuid.v4(),
      photoPath: storedPath,
      title: title.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      createdAt: DateTime.now(),
    );

    await _repo.insertMemory(memory);
    await loadFeed();
    return memory;
  }

  /// Registra una audiografía ya grabada (archivo en [audioPath]) para un
  /// recuerdo existente.
  Future<void> addAudiography({
    required String memoryId,
    required String audioPath,
    required String authorName,
    String? emotionTag,
    required int durationMs,
  }) async {
    final audio = Audiography(
      id: _uuid.v4(),
      memoryId: memoryId,
      audioPath: audioPath,
      authorName: authorName.trim(),
      emotionTag: emotionTag,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    await _repo.insertAudiography(audio);
    await loadFeed();
  }

  /// Edita los metadatos de una audiografía (autor y emoción). El audio en sí
  /// no cambia. Pasa [emotionTag] = null para quitar la etiqueta.
  Future<void> editAudiography({
    required Audiography audio,
    required String authorName,
    String? emotionTag,
  }) async {
    final updated = audio.copyWith(
      authorName: authorName.trim(),
      emotionTag: emotionTag,
      clearEmotion: emotionTag == null,
    );
    await _repo.updateAudiography(updated);
    await loadFeed();
  }

  /// Elimina una sola audiografía (fila + archivo de audio del dispositivo).
  Future<void> deleteAudiography(Audiography audio) async {
    await _repo.deleteAudiography(audio.id);
    await _storage.deleteFile(audio.audioPath);
    await loadFeed();
  }

  Future<void> deleteMemory(Memory memory) async {
    final audios = await _repo.getAudiographies(memory.id);
    await _repo.deleteMemory(memory.id);
    await _storage.deleteFile(memory.photoPath);
    for (final audio in audios) {
      await _storage.deleteFile(audio.audioPath);
    }
    await loadFeed();
  }

  // --- Copia de seguridad local cifrada ---

  /// Genera una copia cifrada de todos los recuerdos. Devuelve los bytes (para
  /// que la pantalla los guarde donde el usuario elija) y un resumen.
  Future<(Uint8List, BackupStats)> createBackup(String password) {
    return _backup.exportEncrypted(password);
  }

  /// Restaura una copia cifrada y recarga el feed. Los elementos se fusionan
  /// por id (restaurar dos veces es seguro).
  Future<BackupStats> restoreBackup(Uint8List bytes, String password) async {
    final stats = await _backup.importEncrypted(bytes, password);
    await loadFeed();
    return stats;
  }
}

class ModerationException implements Exception {
  final String message;
  ModerationException(this.message);
  @override
  String toString() => message;
}
