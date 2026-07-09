import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/media/media_store.dart';
import '../../state/memory_provider.dart';

/// Genera recuerdos de ejemplo (fotos con degradado + voces de muestra) para
/// ver la app con contenido sin crear nada. Solo para demo. Las "voces" son
/// melodías suaves sintetizadas (no hay grabaciones reales incluidas).
const _uuid = Uuid();

class _Voice {
  final String author; // "Nombre, relación"
  final String emotion;
  final double pitch; // frecuencia base para distinguir voces
  const _Voice(this.author, this.emotion, this.pitch);
}

class _Sample {
  final String title;
  final String desc;
  final int c1;
  final int c2;
  final List<_Voice> voices;
  const _Sample(this.title, this.desc, this.c1, this.c2, this.voices);
}

const _samples = <_Sample>[
  _Sample('Verano en la playa', 'Aquel día de sol y risas', 0xFFE9A23B,
      0xFFC7562F, [
    _Voice('Carlos, tu hijo', 'Amor', 220),
    _Voice('Lucía, tu nieta', 'Alegría', 330),
  ]),
  _Sample('La boda de Ana', 'Bailamos hasta el amanecer', 0xFFE86A9B,
      0xFF8E4EC6, [
    _Voice('Ana, tu hija', 'Ternura', 262),
  ]),
  _Sample('Domingo en el campo', 'El aire olía a hierba fresca', 0xFF57B0C9,
      0xFF3E63DD, [
    _Voice('Miguel, tu esposo', 'Paz', 196),
  ]),
  _Sample('Navidad en familia', 'Todos reunidos junto al árbol', 0xFF2FA36B,
      0xFF12A594, [
    _Voice('Carlos, tu hijo', 'Gratitud', 247),
    _Voice('Ana, tu hija', 'Nostalgia', 294),
  ]),
];

Future<Uint8List> _gradientPng(Color a, Color b) async {
  const size = 900.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(size, size), [a, b]);
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);
  final rnd = Random(a.toARGB32() ^ b.toARGB32());
  for (var i = 0; i < 7; i++) {
    canvas.drawCircle(
      Offset(rnd.nextDouble() * size, rnd.nextDouble() * size),
      50 + rnd.nextDouble() * 130,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
  }
  final img =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Sintetiza un WAV mono PCM16 con una melodía suave (arpegio) sobre [pitch].
Uint8List _wavMelody(double pitch, {double seconds = 5}) {
  const sampleRate = 22050;
  final total = (seconds * sampleRate).toInt();
  final notes = [pitch, pitch * 1.25, pitch * 1.5, pitch * 1.25];
  final noteLen = total ~/ notes.length;

  final data = ByteData(44 + total * 2);
  // Cabecera RIFF/WAVE.
  void writeStr(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  final dataLen = total * 2;
  writeStr(0, 'RIFF');
  data.setUint32(4, 36 + dataLen, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  data.setUint32(40, dataLen, Endian.little);

  for (var i = 0; i < total; i++) {
    final noteIdx = (i ~/ noteLen).clamp(0, notes.length - 1);
    final f = notes[noteIdx];
    final tInNote = (i % noteLen) / noteLen;
    // Envolvente suave por nota para evitar clics.
    final env = sin(pi * tInNote);
    final sample = sin(2 * pi * f * i / sampleRate) * env * 0.22;
    data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

Future<void> seedSampleData(MemoryProvider provider) async {
  final tmp = await getTemporaryDirectory();
  for (final s in _samples) {
    final photoBytes = await _gradientPng(Color(s.c1), Color(s.c2));
    final photoPath = p.join(tmp.path, 'seed_${_uuid.v4()}.png');
    await File(photoPath).writeAsBytes(photoBytes, flush: true);

    final memory = await provider.createMemory(
      sourcePhotoPath: photoPath,
      title: s.title,
      description: s.desc,
    );

    for (final v in s.voices) {
      final wav = _wavMelody(v.pitch);
      final ref = await Media.store.saveAudio(wav, ext: 'wav');
      await provider.addAudiography(
        memoryId: memory.id,
        audioPath: ref,
        authorName: v.author,
        emotionTag: v.emotion,
        durationMs: 5000,
      );
    }
  }
}
