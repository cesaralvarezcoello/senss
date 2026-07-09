import 'package:idb_shim/idb_browser.dart';

import '../models/audiography.dart';
import '../models/memory.dart';
import '../models/memory_with_audios.dart';
import '../models/person.dart';
import 'repo_backend.dart';

RepoBackend createRepoBackend() => IdbRepoBackend();

/// Backend web: IndexedDB (via idb_shim). Sin sqlite/WASM. Dos almacenes,
/// `memories` y `audiographies`, con la clave = `id`.
class IdbRepoBackend implements RepoBackend {
  static const _dbName = 'senss_db';
  static const _mem = 'memories';
  static const _aud = 'audiographies';
  static const _ppl = 'people';

  Database? _db;

  Future<Database> _open() async {
    return _db ??= await idbFactoryBrowser.open(
      _dbName,
      version: 2,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_mem)) {
          db.createObjectStore(_mem, keyPath: 'id');
        }
        if (!db.objectStoreNames.contains(_aud)) {
          db.createObjectStore(_aud, keyPath: 'id');
        }
        if (!db.objectStoreNames.contains(_ppl)) {
          db.createObjectStore(_ppl, keyPath: 'id');
        }
      },
    );
  }

  Future<void> _put(String store, Map<String, Object?> value) async {
    final db = await _open();
    final txn = db.transaction(store, idbModeReadWrite);
    await txn.objectStore(store).put(value);
    await txn.completed;
  }

  Future<void> _delete(String store, String key) async {
    final db = await _open();
    final txn = db.transaction(store, idbModeReadWrite);
    await txn.objectStore(store).delete(key);
    await txn.completed;
  }

  Future<List<Map<String, Object?>>> _all(String store) async {
    final db = await _open();
    final txn = db.transaction(store, idbModeReadOnly);
    final out = <Map<String, Object?>>[];
    await for (final c in txn.objectStore(store).openCursor(autoAdvance: true)) {
      out.add(Map<String, Object?>.from(c.value as Map));
    }
    await txn.completed;
    return out;
  }

  Memory _mem_(Map<String, Object?> m) => Memory(
        id: m['id'] as String,
        photoPath: m['photo_path'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
      );

  Audiography _aud_(Map<String, Object?> a) => Audiography(
        id: a['id'] as String,
        memoryId: a['memory_id'] as String,
        audioPath: a['audio_path'] as String,
        authorName: a['author_name'] as String,
        emotionTag: a['emotion_tag'] as String?,
        durationMs: (a['duration_ms'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((a['created_at'] as num).toInt()),
      );

  @override
  Future<void> insertMemory(Memory memory) => _put(_mem, memory.toMap());

  @override
  Future<void> insertAudiography(Audiography audio) => _put(_aud, audio.toMap());

  @override
  Future<void> updateAudiography(Audiography audio) => _put(_aud, audio.toMap());

  @override
  Future<List<MemoryWithAudios>> getFeed() async {
    final mems = (await _all(_mem)).map(_mem_).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final auds = (await _all(_aud)).map(_aud_).toList();

    final grouped = <String, List<Audiography>>{};
    for (final a in auds) {
      grouped.putIfAbsent(a.memoryId, () => []).add(a);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return [
      for (final m in mems) MemoryWithAudios(m, grouped[m.id] ?? const []),
    ];
  }

  @override
  Future<List<Audiography>> getAudiographies(String memoryId) async {
    final auds = (await _all(_aud)).map(_aud_).where((a) => a.memoryId == memoryId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return auds;
  }

  @override
  Future<void> deleteMemory(String id) async {
    await _delete(_mem, id);
    for (final a in await _all(_aud)) {
      if (a['memory_id'] == id) await _delete(_aud, a['id'] as String);
    }
  }

  @override
  Future<void> deleteAudiography(String id) => _delete(_aud, id);

  Person _ppl_(Map<String, Object?> m) => Person(
        id: m['id'] as String,
        name: m['name'] as String,
        relationship: m['relationship'] as String? ?? '',
        portraitPath: m['portrait_path'] as String? ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
      );

  @override
  Future<void> insertPerson(Person person) => _put(_ppl, person.toMap());

  @override
  Future<List<Person>> getPeople() async {
    final list = (await _all(_ppl)).map(_ppl_).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> deletePerson(String id) => _delete(_ppl, id);
}
