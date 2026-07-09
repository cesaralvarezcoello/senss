import '../models/audiography.dart';
import '../models/memory.dart';
import '../models/memory_with_audios.dart';
import 'repo_backend.dart';

export '../models/memory_with_audios.dart';

/// Acceso a datos de recuerdos y audiografías. Delega en el backend agnóstico
/// (sqflite en móvil, IndexedDB en web). Toda la persistencia es local.
class MemoryRepository {
  final RepoBackend _backend;
  MemoryRepository([RepoBackend? backend])
      : _backend = backend ?? createDefaultRepoBackend();

  Future<void> insertMemory(Memory memory) => _backend.insertMemory(memory);

  Future<void> insertAudiography(Audiography audio) =>
      _backend.insertAudiography(audio);

  Future<List<MemoryWithAudios>> getFeed() => _backend.getFeed();

  Future<List<Audiography>> getAudiographies(String memoryId) =>
      _backend.getAudiographies(memoryId);

  Future<void> updateAudiography(Audiography audio) =>
      _backend.updateAudiography(audio);

  Future<void> deleteMemory(String id) => _backend.deleteMemory(id);

  Future<void> deleteAudiography(String id) => _backend.deleteAudiography(id);
}
