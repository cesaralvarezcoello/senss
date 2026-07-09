import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../media/media_store.dart';

/// Reproduce audiografías individuales o en secuencia (una tras otra) para un
/// mismo recuerdo. Envuelve `just_audio` con una única instancia de reproductor
/// y, como [ChangeNotifier], expone **qué ruta está sonando** para que la UI
/// pueda resaltar la fila activa.
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  /// Rutas cargadas en la fuente actual (una sola pista o una secuencia).
  List<String> _queue = const [];

  /// Índice de la pista activa dentro de [_queue] (null si no hay ninguna).
  int? _index;

  AudioPlayerService() {
    // La pista activa cambia sola al avanzar en una secuencia.
    _player.currentIndexStream.listen((i) {
      _index = i;
      notifyListeners();
    });
    _player.playerStateStream.listen((state) {
      // Al terminar la reproducción, ya no hay fila activa que resaltar.
      if (state.processingState == ProcessingState.completed) {
        _index = null;
      }
      notifyListeners();
    });
  }

  /// Posición y duración de la pista activa (para la barra de progreso).
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _player.playing;

  /// Ruta de la audiografía que suena ahora (o null si no hay ninguna).
  String? get currentPath {
    final i = _index;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  /// ¿Es [path] la pista activa (sonando o en pausa)?
  bool isCurrent(String path) => currentPath == path;

  /// Índice de la pista activa dentro de la cola (null si no hay ninguna).
  int? get currentIndex => _index;

  /// Cuántas pistas hay en la cola actual.
  int get queueLength => _queue.length;

  /// Salta a la pista [index] de la cola (para el dial giratorio). Si estaba en
  /// pausa, reanuda; así, girar el dial siempre deja sonando la voz elegida.
  Future<void> skipTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
    _index = index;
    notifyListeners();
    if (!_player.playing) await _player.play();
  }

  /// Reproduce una única audiografía (referencia de medio, agnóstica).
  Future<void> playFile(String ref) async {
    await _player.stop();
    final uri = await Media.store.audioUri(ref);
    if (uri == null) return;
    _queue = [ref];
    _index = 0;
    await _player.setAudioSource(AudioSource.uri(uri));
    notifyListeners();
    await _player.play();
  }

  /// Reproduce varias audiografías en secuencia (el "hilo" de audio-recuerdos).
  Future<void> playSequence(List<String> refs) async {
    if (refs.isEmpty) return;
    await _player.stop();
    final sources = <AudioSource>[];
    final valid = <String>[];
    for (final ref in refs) {
      final uri = await Media.store.audioUri(ref);
      if (uri != null) {
        sources.add(AudioSource.uri(uri));
        valid.add(ref);
      }
    }
    if (sources.isEmpty) return;
    _queue = valid;
    _index = 0;
    await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
    notifyListeners();
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _index = null;
    notifyListeners();
  }

  /// Salta a [position] dentro de la pista activa (scrubber).
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
