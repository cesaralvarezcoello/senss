import 'package:record/record.dart';

/// Envuelve el paquete `record` para grabar audio comprimido (AAC/.m4a)
/// localmente. Mantiene una sola instancia del grabador.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> get isRecording => _recorder.isRecording();

  /// Comienza a grabar en [path]. Usa AAC de baja tasa de bits para no saturar
  /// el almacenamiento del dispositivo.
  Future<void> start(String path) async {
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    );
    await _recorder.start(config, path: path);
  }

  /// Detiene la grabación y devuelve la ruta final del archivo (o null si falló).
  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  /// Amplitud en tiempo real, útil para dibujar un medidor de nivel.
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<void> dispose() => _recorder.dispose();
}
