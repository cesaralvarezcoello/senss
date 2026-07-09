import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../state/memory_provider.dart';

/// Genera recuerdos de ejemplo (fotos con degradado) para poder ver la app con
/// contenido sin tener que crear nada. Solo para demo.
const _uuid = Uuid();

const _samples = <(String, String, int, int)>[
  ('Verano en la playa', 'Aquel día de sol y risas', 0xFFE9A23B, 0xFFC7562F),
  ('La boda de Ana', 'Bailamos hasta el amanecer', 0xFFE86A9B, 0xFF8E4EC6),
  ('Domingo en el campo', 'El aire olía a hierba fresca', 0xFF57B0C9, 0xFF3E63DD),
  ('Navidad en familia', 'Todos reunidos junto al árbol', 0xFF2FA36B, 0xFF12A594),
];

Future<Uint8List> _gradientPng(Color a, Color b) async {
  const size = 900.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..shader = ui.Gradient.linear(
        const Offset(0, 0), const Offset(size, size), [a, b]);
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);
  final rnd = Random(a.value ^ b.value);
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

Future<void> seedSampleData(MemoryProvider provider) async {
  final tmp = await getTemporaryDirectory();
  for (final (title, desc, c1, c2) in _samples) {
    final bytes = await _gradientPng(Color(c1), Color(c2));
    final path = p.join(tmp.path, 'seed_${_uuid.v4()}.png');
    await File(path).writeAsBytes(bytes, flush: true);
    await provider.createMemory(
      sourcePhotoPath: path,
      title: title,
      description: desc,
    );
  }
}
