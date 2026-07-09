import '../models/audiography.dart';
import '../models/memory.dart';
import '../models/memory_with_audios.dart';
import '../models/person.dart';

// Backend por plataforma: sqflite en nativo, IndexedDB en web.
import 'repo_backend_idb.dart' if (dart.library.io) 'repo_backend_sqflite.dart';

/// Acceso a datos **agnóstico** de recuerdos/audiografías. La implementación
/// concreta se elige por plataforma (archivos+sqflite en móvil, IndexedDB en
/// el navegador), sin que el resto de la app lo sepa.
abstract class RepoBackend {
  Future<void> insertMemory(Memory memory);
  Future<void> insertAudiography(Audiography audio);
  Future<List<MemoryWithAudios>> getFeed();
  Future<List<Audiography>> getAudiographies(String memoryId);
  Future<void> updateAudiography(Audiography audio);
  Future<void> deleteMemory(String id);
  Future<void> deleteAudiography(String id);
}

/// Crea el backend por defecto de la plataforma (importación condicional).
RepoBackend createDefaultRepoBackend() => createRepoBackend();
