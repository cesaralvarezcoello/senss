import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:senss/data/models/audiography.dart';
import 'package:senss/data/models/memory.dart';
import 'package:senss/data/repositories/memory_repository.dart';
import 'package:senss/data/services/backup_service.dart';
import 'package:senss/data/services/storage_service.dart';

/// Repositorio falso: sirve un feed fijo y captura lo que se inserta al
/// restaurar. No toca SQLite.
class FakeMemoryRepository extends MemoryRepository {
  FakeMemoryRepository(this.feed);

  List<MemoryWithAudios> feed;
  final List<Memory> insertedMemories = [];
  final List<Audiography> insertedAudios = [];

  @override
  Future<List<MemoryWithAudios>> getFeed() async => feed;

  @override
  Future<void> insertMemory(Memory memory) async =>
      insertedMemories.add(memory);

  @override
  Future<void> insertAudiography(Audiography audio) async =>
      insertedAudios.add(audio);
}

/// Almacenamiento falso: guarda los bytes restaurados en memoria en vez de en
/// el directorio de la app. No toca path_provider.
class FakeStorageService extends StorageService {
  final Map<String, List<int>> photos = {};
  final Map<String, List<int>> audios = {};

  @override
  Future<String> writePhotoBytes(String fileName, List<int> bytes) async {
    photos[fileName] = bytes;
    return 'photos/$fileName';
  }

  @override
  Future<String> writeAudioBytes(String fileName, List<int> bytes) async {
    audios[fileName] = bytes;
    return 'audios/$fileName';
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('senss_backup_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Escribe un archivo real en el temp y devuelve su ruta absoluta.
  String writeTempFile(String name, List<int> bytes) {
    final path = p.join(tmp.path, name);
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  final createdAt = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  MemoryWithAudios sampleItem() {
    final photoBytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final audioBytes = Uint8List.fromList(List.generate(500, (i) => (i * 7) % 256));
    final photoPath = writeTempFile('foto.jpg', photoBytes);
    final audioPath = writeTempFile('nota.m4a', audioBytes);

    final memory = Memory(
      id: 'm1',
      photoPath: photoPath,
      title: 'Verano en la playa',
      description: 'Un día feliz',
      createdAt: createdAt,
    );
    final audio = Audiography(
      id: 'a1',
      memoryId: 'm1',
      audioPath: audioPath,
      authorName: 'Carlos',
      emotionTag: 'Alegría',
      durationMs: 4200,
      createdAt: createdAt,
    );
    return MemoryWithAudios(memory, [audio]);
  }

  group('exportEncrypted', () {
    test('rechaza contraseña vacía', () async {
      final service = BackupService(
        repository: FakeMemoryRepository([]),
        storage: FakeStorageService(),
      );
      expect(
        () => service.exportEncrypted(''),
        throwsA(isA<BackupException>()),
      );
    });

    test('produce un archivo con la cabecera mágica y estadísticas', () async {
      final service = BackupService(
        repository: FakeMemoryRepository([sampleItem()]),
        storage: FakeStorageService(),
      );

      final (bytes, stats) = await service.exportEncrypted('secreta123');

      expect(stats.memories, 1);
      expect(stats.audiographies, 1);
      expect(utf8.decode(bytes.sublist(0, 8)), 'SENSSBK1');
      // No debe contener el JSON en claro (está cifrado).
      expect(utf8.decode(bytes, allowMalformed: true).contains('Carlos'),
          isFalse);
    });
  });

  group('round-trip export -> import', () {
    test('restaura recuerdos, audiografías y bytes de los archivos', () async {
      final original = sampleItem();
      final exporter = BackupService(
        repository: FakeMemoryRepository([original]),
        storage: FakeStorageService(),
      );
      final (bytes, _) = await exporter.exportEncrypted('secreta123');

      final repo = FakeMemoryRepository([]);
      final storage = FakeStorageService();
      final importer = BackupService(repository: repo, storage: storage);

      final stats = await importer.importEncrypted(bytes, 'secreta123');

      expect(stats.memories, 1);
      expect(stats.audiographies, 1);

      // Metadatos del recuerdo.
      expect(repo.insertedMemories, hasLength(1));
      final m = repo.insertedMemories.single;
      expect(m.id, 'm1');
      expect(m.title, 'Verano en la playa');
      expect(m.description, 'Un día feliz');
      expect(m.createdAt, createdAt);

      // Metadatos de la audiografía.
      expect(repo.insertedAudios, hasLength(1));
      final a = repo.insertedAudios.single;
      expect(a.id, 'a1');
      expect(a.memoryId, 'm1');
      expect(a.authorName, 'Carlos');
      expect(a.emotionTag, 'Alegría');
      expect(a.durationMs, 4200);

      // Los bytes de los archivos sobreviven intactos.
      expect(storage.photos['foto.jpg'],
          File(original.memory.photoPath).readAsBytesSync());
      expect(storage.audios['nota.m4a'],
          File(original.audios.single.audioPath).readAsBytesSync());

      // Las rutas se reescriben al almacenamiento del dispositivo actual.
      expect(m.photoPath, 'photos/foto.jpg');
      expect(a.audioPath, 'audios/nota.m4a');
    });

    test('restaurar dos veces es seguro (idempotente por id)', () async {
      final exporter = BackupService(
        repository: FakeMemoryRepository([sampleItem()]),
        storage: FakeStorageService(),
      );
      final (bytes, _) = await exporter.exportEncrypted('secreta123');

      final repo = FakeMemoryRepository([]);
      final importer =
          BackupService(repository: repo, storage: FakeStorageService());

      await importer.importEncrypted(bytes, 'secreta123');
      await importer.importEncrypted(bytes, 'secreta123');

      // Se vuelven a insertar los mismos ids (el repo real usa REPLACE).
      expect(repo.insertedMemories.map((m) => m.id), ['m1', 'm1']);
    });
  });

  group('importEncrypted rechaza entradas inválidas', () {
    Future<Uint8List> validBackup() async {
      final service = BackupService(
        repository: FakeMemoryRepository([sampleItem()]),
        storage: FakeStorageService(),
      );
      final (bytes, _) = await service.exportEncrypted('secreta123');
      return bytes;
    }

    BackupService importer() => BackupService(
          repository: FakeMemoryRepository([]),
          storage: FakeStorageService(),
        );

    test('contraseña incorrecta', () async {
      final bytes = await validBackup();
      expect(
        () => importer().importEncrypted(bytes, 'incorrecta'),
        throwsA(isA<BackupException>()),
      );
    });

    test('archivo alterado (un byte cambiado en el ciphertext)', () async {
      final bytes = await validBackup();
      // Cambia un byte bien dentro del ciphertext (tras la cabecera de 36).
      bytes[bytes.length - 20] = bytes[bytes.length - 20] ^ 0xFF;
      expect(
        () => importer().importEncrypted(bytes, 'secreta123'),
        throwsA(isA<BackupException>()),
      );
    });

    test('cabecera mágica incorrecta', () async {
      final bytes = Uint8List.fromList(
          utf8.encode('NOPESIGX') + List.filled(100, 0));
      expect(
        () => importer().importEncrypted(bytes, 'secreta123'),
        throwsA(isA<BackupException>()),
      );
    });

    test('archivo demasiado corto', () async {
      final bytes = Uint8List.fromList(utf8.encode('SENSSBK1'));
      expect(
        () => importer().importEncrypted(bytes, 'secreta123'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
