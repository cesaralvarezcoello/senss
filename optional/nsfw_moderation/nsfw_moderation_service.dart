import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'moderation_service.dart';

/// Cómo normalizar los valores de pixel (0–255) antes de la inferencia. Debe
/// coincidir con cómo se entrenó el modelo.
enum PixelNormalization {
  /// `v / 255` → rango `[0, 1]` (lo más común).
  zeroToOne,

  /// `v / 127.5 - 1` → rango `[-1, 1]`.
  minusOneToOne,

  /// Sin normalizar → rango `[0, 255]`.
  raw,
}

/// Carga (perezosa) del intérprete TFLite. Inyectable para pruebas.
typedef InterpreterLoader = Future<Interpreter> Function();

/// Moderación **real y 100% on-device**: un clasificador NSFW en TensorFlow
/// Lite decide si una foto es apta antes de guardarla. Ningún pixel sale del
/// dispositivo.
///
/// El modelo se carga de forma perezosa desde los assets. Si el archivo no
/// existe o no se puede cargar, el servicio **degrada de forma segura**: por
/// defecto aprueba el contenido (para no bloquear la app) y avisa en consola.
/// Pon [blockOnUnavailable] en `true` si prefieres fallar cerrado.
///
/// Ver `assets/models/README.md` para qué modelo colocar y cómo configurarlo.
class NsfwModerationService implements ModerationService {
  final String assetPath;

  /// Probabilidad mínima de contenido no-seguro para bloquear (0–1).
  final double threshold;

  /// Índices de las clases consideradas "no seguras" en la salida del modelo.
  /// Por defecto, disposición de 5 clases estilo GantMan
  /// `[drawings, hentai, neutral, porn, sexy]` → hentai, porn, sexy.
  final List<int> unsafeClassIndices;

  final PixelNormalization normalization;

  /// Si no hay modelo disponible: `false` aprueba (por defecto), `true` bloquea.
  final bool blockOnUnavailable;

  final InterpreterLoader _loader;

  NsfwModerationService({
    String assetPath = 'assets/models/nsfw.tflite',
    this.threshold = 0.7,
    this.unsafeClassIndices = const [1, 3, 4],
    this.normalization = PixelNormalization.zeroToOne,
    this.blockOnUnavailable = false,
    InterpreterLoader? interpreterLoader,
  })  : assetPath = assetPath,
        _loader = interpreterLoader ?? (() => Interpreter.fromAsset(assetPath));

  Interpreter? _interpreter;
  bool _triedLoading = false;
  bool _unavailable = false;

  Future<void> _ensureLoaded() async {
    if (_triedLoading) return;
    _triedLoading = true;
    try {
      _interpreter = await _loader();
    } catch (e) {
      _unavailable = true;
      debugPrint(
        'NsfwModerationService: modelo no disponible en "$assetPath" '
        '($e). La moderación aprobará todo. Añade el modelo antes de publicar '
        '(ver assets/models/README.md).',
      );
    }
  }

  @override
  Future<ModerationResult> reviewImage(File image) async {
    await _ensureLoaded();
    final interpreter = _interpreter;
    if (_unavailable || interpreter == null) {
      return blockOnUnavailable
          ? const ModerationResult.blocked(
              'La verificación de la imagen no está disponible en este '
              'dispositivo.')
          : const ModerationResult.allowed();
    }

    try {
      final decoded = img.decodeImage(await image.readAsBytes());
      if (decoded == null) {
        // No se pudo leer la imagen: no la bloqueamos por un fallo técnico.
        return const ModerationResult.allowed();
      }

      final inShape = interpreter.getInputTensor(0).shape; // [1, h, w, 3]
      final input = buildInput(decoded, inShape[2], inShape[1], normalization);
      final outShape = interpreter.getOutputTensor(0).shape;
      final outputCount = outShape.fold<int>(1, (a, b) => a * b);
      final output = List.filled(outputCount, 0.0).reshape(outShape);

      interpreter.run(input, output);

      final probs = (output[0] as List).cast<double>();
      final unsafe = unsafeScore(probs, unsafeClassIndices);

      if (unsafe >= threshold) {
        return const ModerationResult.blocked(
          'Esta imagen no parece adecuada para senss, un espacio de recuerdos '
          'positivos. Prueba con otra foto.',
        );
      }
      return const ModerationResult.allowed();
    } catch (e) {
      // Cualquier fallo de inferencia degrada de forma segura.
      debugPrint('NsfwModerationService: fallo al analizar la imagen ($e).');
      return blockOnUnavailable
          ? const ModerationResult.blocked(
              'No se pudo verificar la imagen. Inténtalo de nuevo.')
          : const ModerationResult.allowed();
    }
  }

  /// Suma de probabilidades de las clases no-seguras. Con una única salida
  /// (sigmoide) se interpreta directamente como probabilidad no-segura. Los
  /// índices fuera de rango se ignoran.
  @visibleForTesting
  static double unsafeScore(List<double> probs, List<int> unsafeClassIndices) {
    if (probs.length == 1) return probs.first;
    var score = 0.0;
    for (final i in unsafeClassIndices) {
      if (i >= 0 && i < probs.length) score += probs[i];
    }
    return score;
  }

  /// Normaliza un valor de canal (0–255) según [normalization].
  @visibleForTesting
  static double normalizeValue(double v, PixelNormalization normalization) {
    switch (normalization) {
      case PixelNormalization.zeroToOne:
        return v / 255.0;
      case PixelNormalization.minusOneToOne:
        return v / 127.5 - 1.0;
      case PixelNormalization.raw:
        return v;
    }
  }

  /// Construye el tensor de entrada `[1, alto, ancho, 3]` redimensionando y
  /// normalizando la foto según lo que espera el modelo.
  @visibleForTesting
  static List<List<List<List<double>>>> buildInput(
    img.Image source,
    int width,
    int height,
    PixelNormalization normalization,
  ) {
    final resized = img.copyResize(source, width: width, height: height);
    return [
      List.generate(height, (y) {
        return List.generate(width, (x) {
          final px = resized.getPixel(x, y);
          return [
            normalizeValue(px.r.toDouble(), normalization),
            normalizeValue(px.g.toDouble(), normalization),
            normalizeValue(px.b.toDouble(), normalization),
          ];
        });
      }),
    ];
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
