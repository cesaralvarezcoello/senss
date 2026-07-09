import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/media/media_store.dart';
import '../data/models/audiography.dart';
import '../data/models/memory.dart';
import '../data/models/person.dart';
import '../data/repositories/memory_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/moderation_service.dart';

/// Estado central del feed. Orquesta repositorio + almacenamiento de medios
/// (agnóstico) + moderación, y notifica a la UI cuando cambian los recuerdos.
class MemoryProvider extends ChangeNotifier {
  final MemoryRepository _repo;
  final ModerationService _moderation;
  final BackupService _backup;
  static const _uuid = Uuid();

  MemoryProvider({
    MemoryRepository? repository,
    ModerationService? moderation,
    BackupService? backup,
  })  : _repo = repository ?? MemoryRepository(),
        _moderation = moderation ?? PermissiveModerationService(),
        _backup = backup ??
            BackupService(repository: repository ?? MemoryRepository());

  List<MemoryWithAudios> _feed = const [];
  List<MemoryWithAudios> get feed => _feed;

  List<Person> _people = const [];
  List<Person> get people => _people;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadFeed() async {
    _loading = true;
    notifyListeners();
    try {
      _feed = await _repo.getFeed();
      _people = await _repo.getPeople();
    } catch (e) {
      debugPrint('loadFeed error: $e');
      _feed = const [];
      _people = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addPerson({
    required Uint8List portraitBytes,
    String ext = 'jpg',
    required String name,
    String relationship = '',
  }) async {
    final ref = portraitBytes.isEmpty
        ? ''
        : await Media.store.savePhoto(portraitBytes, ext: ext);
    final person = Person(
      id: _uuid.v4(),
      name: name.trim(),
      relationship: relationship.trim(),
      portraitPath: ref,
      createdAt: DateTime.now(),
    );
    await _repo.insertPerson(person);
    await loadFeed();
  }

  Future<void> deletePerson(Person person) async {
    await _repo.deletePerson(person.id);
    if (person.portraitPath.isNotEmpty) {
      await Media.store.delete(person.portraitPath);
    }
    await loadFeed();
  }

  /// Crea un recuerdo a partir de los bytes de una foto (tomada/importada).
  /// Devuelve el recuerdo creado, o lanza [ModerationException] si la imagen
  /// no pasa la moderación local.
  Future<Memory> createMemory({
    required Uint8List photoBytes,
    String ext = 'jpg',
    required String title,
    String? description,
  }) async {
    final review = await _moderation.reviewImage(photoBytes);
    if (!review.allowed) {
      throw ModerationException(review.reason ??
          'La imagen no cumple con las normas del entorno seguro.');
    }

    final ref = await Media.store.savePhoto(photoBytes, ext: ext);
    final memory = Memory(
      id: _uuid.v4(),
      photoPath: ref,
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

  /// Registra una audiografía ya grabada (referencia en [audioPath]).
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

  /// Elimina una sola audiografía (fila + medio).
  Future<void> deleteAudiography(Audiography audio) async {
    await _repo.deleteAudiography(audio.id);
    await Media.store.delete(audio.audioPath);
    await loadFeed();
  }

  Future<void> deleteMemory(Memory memory) async {
    final audios = await _repo.getAudiographies(memory.id);
    await _repo.deleteMemory(memory.id);
    await Media.store.delete(memory.photoPath);
    for (final audio in audios) {
      await Media.store.delete(audio.audioPath);
    }
    await loadFeed();
  }

  // --- Copia de seguridad local cifrada ---

  Future<(Uint8List, BackupStats)> createBackup(String password) {
    return _backup.exportEncrypted(password);
  }

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
