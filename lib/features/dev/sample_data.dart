import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/media/media_store.dart';
import '../../state/memory_provider.dart';

/// Genera recuerdos de ejemplo (fotos con degradado + voces de muestra) para
/// ver la app con contenido sin crear nada. Solo para demo. Las "voces" son
/// melodías suaves sintetizadas (no hay grabaciones reales incluidas).

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
  final rnd = Random(a.toARGB32() ^ b.toARGB32());

  // Base: degradado cálido.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.linear(
          const Offset(0, 0), const Offset(size, size), [a, b]),
  );

  // Brillos de colores vivos, mezclados de forma aditiva (más luminoso).
  final baseHue = HSLColor.fromColor(a).hue;
  for (var i = 0; i < 5; i++) {
    final hue = (baseHue + i * 67) % 360;
    final glow = HSLColor.fromAHSL(1, hue, 0.85, 0.6).toColor();
    final center = Offset(rnd.nextDouble() * size, rnd.nextDouble() * size);
    final radius = size * (0.28 + rnd.nextDouble() * 0.32);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(center, radius, [
          glow.withValues(alpha: 0.55),
          glow.withValues(alpha: 0.0),
        ]),
    );
  }

  // Destellos suaves (bokeh).
  for (var i = 0; i < 9; i++) {
    canvas.drawCircle(
      Offset(rnd.nextDouble() * size, rnd.nextDouble() * size),
      18 + rnd.nextDouble() * 70,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: 0.06 + rnd.nextDouble() * 0.12),
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
  for (final s in _samples) {
    final photoBytes = await _gradientPng(Color(s.c1), Color(s.c2));
    final memory = await provider.createMemory(
      photoBytes: photoBytes,
      ext: 'png',
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
