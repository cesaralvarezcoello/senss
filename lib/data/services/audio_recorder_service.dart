import 'package:record/record.dart';

import '../media/media_store.dart';
import 'recorder_bytes.dart';

/// Envuelve el paquete `record` para grabar audio localmente, de forma
/// **multiplataforma**:
/// - Nativo: graba a un archivo (la ruta es la referencia del medio).
/// - Web: grada a un blob; al detener, se leen sus bytes y se guardan en la
///   capa de medios (IndexedDB). Nada sale del dispositivo/navegador.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Ruta de archivo en nativo (null en web).
  String? _ioPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    _ioPath = await Media.store.newRecordingPath();
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    );
    await _recorder.start(config, path: _ioPath ?? '');
  }

  /// Detiene y guarda el audio. Devuelve la referencia del medio (o null).
  Future<String?> stopAndSave() async {
    final result = await _recorder.stop();
    if (_ioPath != null) {
      // Nativo: el archivo ya quedó guardado; la ruta es la referencia.
      return _ioPath;
    }
    // Web: `result` es una URL de blob. Leemos sus bytes y los persistimos.
    if (result == null) return null;
    final data = await fetchRecordingBytes(result);
    if (data == null) return null;
    return Media.store.saveAudio(data.$1, ext: _extFromMime(data.$2));
  }

  Future<void> cancel() => _recorder.cancel();

  /// Amplitud en tiempo real (para dibujar un medidor de nivel).
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<void> dispose() => _recorder.dispose();

  String _extFromMime(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('webm')) return 'webm';
    if (m.contains('ogg')) return 'ogg';
    if (m.contains('wav')) return 'wav';
    if (m.contains('mpeg') || m.contains('mp3')) return 'mp3';
    return 'm4a'; // aac / mp4
  }
}
