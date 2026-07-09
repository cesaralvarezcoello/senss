import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/audiography.dart';
import '../models/memory.dart';
import '../models/person.dart';

/// Inicializa y expone la base de datos SQLite local (100% en el dispositivo).
///
/// Solo se guardan metadatos y rutas de archivos aquí; las fotos y audios
/// viven como archivos en el almacenamiento privado de la app.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'senss.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Necesario para que ON DELETE CASCADE funcione.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createPeople(db);
      },
    );
  }

  Future<void> _createPeople(Database db) async {
    await db.execute('''
      CREATE TABLE ${Person.table} (
        id            TEXT    PRIMARY KEY,
        name          TEXT    NOT NULL,
        relationship  TEXT,
        portrait_path TEXT,
        created_at    INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createSchema(Database db, int version) async {
    await _createPeople(db);
    await db.execute('''
      CREATE TABLE ${Memory.table} (
        id          TEXT    PRIMARY KEY,
        photo_path  TEXT    NOT NULL,
        title       TEXT    NOT NULL,
        description TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${Audiography.table} (
        id          TEXT    PRIMARY KEY,
        memory_id   TEXT    NOT NULL,
        audio_path  TEXT    NOT NULL,
        author_name TEXT    NOT NULL,
        emotion_tag TEXT,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        FOREIGN KEY (memory_id) REFERENCES ${Memory.table} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_audiographies_memory
      ON ${Audiography.table} (memory_id, created_at)
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
