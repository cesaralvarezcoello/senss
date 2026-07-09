import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senss/data/media/media_store.dart';
import 'package:senss/data/models/audiography.dart';
import 'package:senss/data/models/memory.dart';
import 'package:senss/data/repositories/memory_repository.dart';
import 'package:senss/data/services/backup_service.dart';

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

/// Almacén de medios falso en memoria (sin archivos ni IndexedDB).
class FakeMediaStore implements MediaStore {
  final Map<String, Uint8List> data = {};
  int _n = 0;

  @override
  String get label => 'fake';

  void put(String ref, Uint8List bytes) => data[ref] = bytes;

  @override
  Future<String> savePhoto(Uint8List bytes, {String ext = 'jpg'}) async {
    final ref = 'p${_n++}.$ext';
    data[ref] = bytes;
    return ref;
  }

  @override
  Future<String> saveAudio(Uint8List bytes, {String ext = 'm4a'}) async {
    final ref = 'a${_n++}.$ext';
    data[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> readBytes(String ref) async => data[ref];

  @override
  Future<void> delete(String ref) async => data.remove(ref);

  @override
  Future<ImageProvider> imageProvider(String ref) async =>
      MemoryImage(data[ref] ?? Uint8List(0));

  @override
  Future<Uri?> audioUri(String ref) async => null;

  @override
  Future<String?> newRecordingPath() async => null;
}

void main() {
  late FakeMediaStore store;

  setUp(() {
    store = FakeMediaStore();
    Media.use(store);
  });

  final createdAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  MemoryWithAudios sampleItem() {
    final photoBytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final audioBytes =
        Uint8List.fromList(List.generate(500, (i) => (i * 7) % 256));
    store.put('foto.jpg', photoBytes);
    store.put('nota.m4a', audioBytes);

    final memory = Memory(
      id: 'm1',
      photoPath: 'foto.jpg',
      title: 'Verano en la playa',
      description: 'Un día feliz',
      createdAt: createdAt,
    );
    final audio = Audiography(
      id: 'a1',
      memoryId: 'm1',
      audioPath: 'nota.m4a',
      authorName: 'Carlos',
      emotionTag: 'Alegría',
      durationMs: 4200,
      createdAt: createdAt,
    );
    return MemoryWithAudios(memory, [audio]);
  }

  group('exportEncrypted', () {
    test('rechaza contraseña vacía', () async {
      final service = BackupService(repository: FakeMemoryRepository([]));
      expect(() => service.exportEncrypted(''),
          throwsA(isA<BackupException>()));
    });

    test('produce un archivo con la cabecera mágica y estadísticas', () async {
      final service =
          BackupService(repository: FakeMemoryRepository([sampleItem()]));
      final (bytes, stats) = await service.exportEncrypted('secreta123');

      expect(stats.memories, 1);
      expect(stats.audiographies, 1);
      expect(utf8.decode(bytes.sublist(0, 8)), 'SENSSBK1');
      expect(utf8.decode(bytes, allowMalformed: true).contains('Carlos'),
          isFalse);
    });
  });

  group('round-trip export -> import', () {
    test('restaura recuerdos, audiografías y bytes de los medios', () async {
      final original = sampleItem();
      final exporter =
          BackupService(repository: FakeMemoryRepository([original]));
      final (bytes, _) = await exporter.exportEncrypted('secreta123');

      final repo = FakeMemoryRepository([]);
      final importer = BackupService(repository: repo);
      final stats = await importer.importEncrypted(bytes, 'secreta123');

      expect(stats.memories, 1);
      expect(stats.audiographies, 1);

      final m = repo.insertedMemories.single;
      expect(m.id, 'm1');
      expect(m.title, 'Verano en la playa');
      expect(m.description, 'Un día feliz');
      expect(m.createdAt, createdAt);

      final a = repo.insertedAudios.single;
      expect(a.id, 'a1');
      expect(a.authorName, 'Carlos');
      expect(a.emotionTag, 'Alegría');
      expect(a.durationMs, 4200);

      // Los bytes de los medios sobreviven intactos.
      expect(await store.readBytes(m.photoPath), store.data['foto.jpg']);
      expect(await store.readBytes(a.audioPath), store.data['nota.m4a']);
    });
  });

  group('importEncrypted rechaza entradas inválidas', () {
    Future<Uint8List> validBackup() async {
      final service =
          BackupService(repository: FakeMemoryRepository([sampleItem()]));
      final (bytes, _) = await service.exportEncrypted('secreta123');
      return bytes;
    }

    BackupService importer() =>
        BackupService(repository: FakeMemoryRepository([]));

    test('contraseña incorrecta', () async {
      final bytes = await validBackup();
      expect(() => importer().importEncrypted(bytes, 'incorrecta'),
          throwsA(isA<BackupException>()));
    });

    test('archivo alterado', () async {
      final bytes = await validBackup();
      bytes[bytes.length - 20] = bytes[bytes.length - 20] ^ 0xFF;
      expect(() => importer().importEncrypted(bytes, 'secreta123'),
          throwsA(isA<BackupException>()));
    });

    test('cabecera mágica incorrecta', () async {
      final bytes =
          Uint8List.fromList(utf8.encode('NOPESIGX') + List.filled(100, 0));
      expect(() => importer().importEncrypted(bytes, 'secreta123'),
          throwsA(isA<BackupException>()));
    });

    test('archivo demasiado corto', () async {
      final bytes = Uint8List.fromList(utf8.encode('SENSSBK1'));
      expect(() => importer().importEncrypted(bytes, 'secreta123'),
          throwsA(isA<BackupException>()));
    });
  });
}
