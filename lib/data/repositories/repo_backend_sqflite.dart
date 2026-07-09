import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/audiography.dart';
import '../models/memory.dart';
import '../models/memory_with_audios.dart';
import '../models/person.dart';
import 'repo_backend.dart';

RepoBackend createRepoBackend() => SqfliteRepoBackend();

/// Backend nativo: SQLite (sqflite).
class SqfliteRepoBackend implements RepoBackend {
  final AppDatabase _db;
  SqfliteRepoBackend([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  @override
  Future<void> insertMemory(Memory memory) async {
    final db = await _db.database;
    await db.insert(Memory.table, memory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> insertAudiography(Audiography audio) async {
    final db = await _db.database;
    await db.insert(Audiography.table, audio.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<MemoryWithAudios>> getFeed() async {
    final db = await _db.database;
    final memoryRows = await db.query(Memory.table, orderBy: 'created_at DESC');
    if (memoryRows.isEmpty) return [];
    final audioRows =
        await db.query(Audiography.table, orderBy: 'created_at ASC');

    final grouped = <String, List<Audiography>>{};
    for (final row in audioRows) {
      final audio = Audiography.fromMap(row);
      grouped.putIfAbsent(audio.memoryId, () => []).add(audio);
    }
    return memoryRows.map((row) {
      final memory = Memory.fromMap(row);
      return MemoryWithAudios(memory, grouped[memory.id] ?? const []);
    }).toList();
  }

  @override
  Future<List<Audiography>> getAudiographies(String memoryId) async {
    final db = await _db.database;
    final rows = await db.query(Audiography.table,
        where: 'memory_id = ?', whereArgs: [memoryId], orderBy: 'created_at ASC');
    return rows.map(Audiography.fromMap).toList();
  }

  @override
  Future<void> updateAudiography(Audiography audio) async {
    final db = await _db.database;
    await db.update(Audiography.table, audio.toMap(),
        where: 'id = ?', whereArgs: [audio.id]);
  }

  @override
  Future<void> deleteMemory(String id) async {
    final db = await _db.database;
    // ON DELETE CASCADE elimina también las audiografías asociadas.
    await db.delete(Memory.table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAudiography(String id) async {
    final db = await _db.database;
    await db.delete(Audiography.table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> insertPerson(Person person) async {
    final db = await _db.database;
    await db.insert(Person.table, person.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Person>> getPeople() async {
    final db = await _db.database;
    final rows = await db.query(Person.table, orderBy: 'created_at ASC');
    return rows.map(Person.fromMap).toList();
  }

  @override
  Future<void> deletePerson(String id) async {
    final db = await _db.database;
    await db.delete(Person.table, where: 'id = ?', whereArgs: [id]);
  }
}
