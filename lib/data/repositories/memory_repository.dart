import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/audiography.dart';
import '../models/memory.dart';

/// Un recuerdo junto con todas sus audiografías, listo para mostrar en el feed.
class MemoryWithAudios {
  final Memory memory;
  final List<Audiography> audios;
  const MemoryWithAudios(this.memory, this.audios);
}

/// Acceso a datos para recuerdos y audiografías. Toda la persistencia es local.
class MemoryRepository {
  final AppDatabase _db;
  MemoryRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<void> insertMemory(Memory memory) async {
    final db = await _db.database;
    await db.insert(
      Memory.table,
      memory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAudiography(Audiography audio) async {
    final db = await _db.database;
    await db.insert(
      Audiography.table,
      audio.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Feed principal: recuerdos más recientes primero, cada uno con sus audios
  /// ordenados cronológicamente (el primero grabado arriba).
  Future<List<MemoryWithAudios>> getFeed() async {
    final db = await _db.database;

    final memoryRows = await db.query(
      Memory.table,
      orderBy: 'created_at DESC',
    );
    if (memoryRows.isEmpty) return [];

    final audioRows = await db.query(
      Audiography.table,
      orderBy: 'created_at ASC',
    );

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

  Future<List<Audiography>> getAudiographies(String memoryId) async {
    final db = await _db.database;
    final rows = await db.query(
      Audiography.table,
      where: 'memory_id = ?',
      whereArgs: [memoryId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Audiography.fromMap).toList();
  }

  Future<void> deleteMemory(String id) async {
    final db = await _db.database;
    // ON DELETE CASCADE elimina también las audiografías asociadas.
    await db.delete(Memory.table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAudiography(Audiography audio) async {
    final db = await _db.database;
    await db.update(
      Audiography.table,
      audio.toMap(),
      where: 'id = ?',
      whereArgs: [audio.id],
    );
  }

  Future<void> deleteAudiography(String id) async {
    final db = await _db.database;
    await db.delete(Audiography.table, where: 'id = ?', whereArgs: [id]);
  }
}
