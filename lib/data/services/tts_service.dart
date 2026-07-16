import 'package:flutter_tts/flutter_tts.dart';

/// La **voz de senss**: texto a voz on-device (voz del sistema), para el modo
/// conversación. Habla pausado y claro (pensado para adultos mayores) y espera
/// a terminar cada frase, para poder encadenar habla → escucha sin pisarse.
///
/// Todo ocurre en el dispositivo; no interviene ningún servidor.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    try {
      // Con esto, speak() completa su Future cuando termina de hablar.
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.55); // ritmo natural, claro pero sin arrastrar.
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Si la voz del sistema no está lista, seguimos: el modo funciona igual
      // con los subtítulos y los botones grandes.
    }
    _ready = true;
  }

  /// Dice [text] y espera a terminar (o retorna si falla / está vacío).
  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensure();
    try {
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _tts.stop();
  }
}
