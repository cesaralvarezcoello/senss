import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:senss/data/services/nsfw_moderation_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Cargador que simula la ausencia del modelo (no toca código nativo).
Future<Interpreter> failingLoader() async =>
    throw Exception('modelo no disponible');

void main() {
  group('normalizeValue', () {
    test('zeroToOne', () {
      expect(NsfwModerationService.normalizeValue(0, PixelNormalization.zeroToOne),
          0.0);
      expect(
          NsfwModerationService.normalizeValue(255, PixelNormalization.zeroToOne),
          1.0);
      expect(
          NsfwModerationService.normalizeValue(128, PixelNormalization.zeroToOne),
          closeTo(128 / 255, 1e-9));
    });

    test('minusOneToOne', () {
      expect(
          NsfwModerationService.normalizeValue(
              0, PixelNormalization.minusOneToOne),
          -1.0);
      expect(
          NsfwModerationService.normalizeValue(
              255, PixelNormalization.minusOneToOne),
          1.0);
      expect(
          NsfwModerationService.normalizeValue(
              127.5, PixelNormalization.minusOneToOne),
          closeTo(0.0, 1e-9));
    });

    test('raw', () {
      expect(NsfwModerationService.normalizeValue(200, PixelNormalization.raw),
          200.0);
    });
  });

  group('unsafeScore', () {
    test('salida sigmoide de un valor se usa directamente', () {
      expect(NsfwModerationService.unsafeScore([0.83], const [1, 3, 4]),
          closeTo(0.83, 1e-9));
    });

    test('suma las probabilidades de las clases no-seguras (5 clases)', () {
      // [drawings, hentai, neutral, porn, sexy]
      final probs = [0.10, 0.20, 0.30, 0.05, 0.35];
      expect(NsfwModerationService.unsafeScore(probs, const [1, 3, 4]),
          closeTo(0.60, 1e-9));
    });

    test('ignora índices fuera de rango', () {
      expect(NsfwModerationService.unsafeScore([0.5, 0.5], const [1, 3]),
          closeTo(0.5, 1e-9));
    });
  });

  group('buildInput', () {
    test('normaliza y ordena los canales RGB de cada pixel', () {
      final image = img.Image(width: 1, height: 1);
      image.setPixelRgb(0, 0, 255, 128, 0);

      final input = NsfwModerationService.buildInput(
          image, 1, 1, PixelNormalization.zeroToOne);

      expect(input.length, 1); // batch
      expect(input[0].length, 1); // alto
      expect(input[0][0].length, 1); // ancho
      final pixel = input[0][0][0];
      expect(pixel[0], closeTo(1.0, 1e-9)); // r
      expect(pixel[1], closeTo(128 / 255, 1e-9)); // g
      expect(pixel[2], 0.0); // b
    });

    test('redimensiona a las dimensiones que pide el modelo', () {
      final image = img.Image(width: 2, height: 2);
      final input = NsfwModerationService.buildInput(
          image, 4, 3, PixelNormalization.raw);

      expect(input[0].length, 3); // alto
      expect(input[0][0].length, 4); // ancho
      expect(input[0][0][0].length, 3); // canales
    });
  });

  group('degradación segura cuando falta el modelo', () {
    late File dummy;

    setUp(() {
      dummy = File('${Directory.systemTemp.path}/senss_dummy_image.bin')
        ..writeAsBytesSync([0, 1, 2, 3]);
    });

    tearDown(() {
      if (dummy.existsSync()) dummy.deleteSync();
    });

    test('por defecto aprueba (no bloquea la app)', () async {
      final service =
          NsfwModerationService(interpreterLoader: failingLoader);
      final result = await service.reviewImage(dummy);
      expect(result.allowed, isTrue);
    });

    test('con blockOnUnavailable: true, bloquea con un motivo', () async {
      final service = NsfwModerationService(
        interpreterLoader: failingLoader,
        blockOnUnavailable: true,
      );
      final result = await service.reviewImage(dummy);
      expect(result.allowed, isFalse);
      expect(result.reason, isNotNull);
    });
  });
}
