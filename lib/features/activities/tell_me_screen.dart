import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/audio_recorder_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import 'activity_kit.dart';

/// Reminiscencia: mira una foto, escucha sus voces y **cuenta tu propio
/// recuerdo**. Lo que dices se guarda como una voz nueva del recuerdo — así el
/// hilo crece con la propia voz de la persona.
class TellMeScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const TellMeScreen({super.key, required this.feed});

  @override
  State<TellMeScreen> createState() => _TellMeScreenState();
}

class _TellMeScreenState extends State<TellMeScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  final _recorder = AudioRecorderService();

  late MemoryWithAudios _memory;
  bool _recording = false;
  bool _busy = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _memory = _picker.pick(widget.feed);
  }

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _playVoices() {
    if (_memory.audios.isEmpty) return;
    _player.playSequence(_memory.audios.map((a) => a.audioPath).toList());
  }

  void _another() {
    _player.stop();
    setState(() => _memory = _picker.pick(widget.feed));
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _snack('Necesitamos permiso para usar el micrófono.');
      return;
    }
    await _player.stop();
    await _recorder.startRecording();
    setState(() {
      _recording = true;
      _startedAt = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    setState(() => _busy = true);
    final ref = await _recorder.stopAndSave();
    final ms = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    if (ref != null) {
      await context.read<MemoryProvider>().addAudiography(
            memoryId: _memory.memory.id,
            audioPath: ref,
            authorName: 'Mi voz',
            emotionTag: null,
            durationMs: ms,
          );
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _busy = false;
    });
    if (ref == null) {
      _snack('No se pudo guardar la grabación. Inténtalo de nuevo.');
      return;
    }
    await showCelebration(context,
        message: '¡Gracias por contarme!',
        sub: 'Tu recuerdo quedó guardado.',
        nextLabel: 'Otra foto');
    if (mounted) _another();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final hasVoices = _memory.audios.isNotEmpty;
    return ActivityShell(
      title: 'Cuéntame de este día',
      child: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: memoryThumb(_memory.memory.photoPath, radius: AppRadius.lg),
          ),
          const SizedBox(height: AppSpace.md),
          AppText(_memory.memory.title, variant: AppTextVariant.titleL),
          const SizedBox(height: AppSpace.lg),
          if (hasVoices)
            AppButton(
              label: 'Escuchar las voces',
              icon: Icons.volume_up_rounded,
              variant: AppButtonVariant.tonal,
              onPressed: _playVoices,
            ),
          const SizedBox(height: AppSpace.xl),
          Center(
            child: Column(
              children: [
                AppText(
                  _recording
                      ? 'Cuenta tu recuerdo… toca para terminar'
                      : '¿Qué recuerdas de este día?',
                  variant: AppTextVariant.bodyStrong,
                  align: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.lg),
                _RecordButton(
                  recording: _recording,
                  busy: _busy,
                  onTap: _busy
                      ? null
                      : (_recording ? _stopRecording : _startRecording),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          if (!_recording)
            AppButton(
              label: 'Otra foto',
              icon: Icons.arrow_forward_rounded,
              variant: AppButtonVariant.ghost,
              onPressed: _another,
            ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool recording;
  final bool busy;
  final VoidCallback? onTap;
  const _RecordButton(
      {required this.recording, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = recording ? c.danger : c.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 28,
                spreadRadius: 2),
          ],
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(34),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              )
            : Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white, size: 52),
      ),
    );
  }
}
