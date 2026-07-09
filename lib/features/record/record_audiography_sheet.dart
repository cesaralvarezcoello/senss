import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/services/audio_recorder_service.dart';
import '../../state/memory_provider.dart';

/// Hoja inferior para grabar una audiografía y adjuntarla a un recuerdo.
/// Flujo: aceptar términos -> grabar -> poner autor y emoción -> guardar.
class RecordAudiographySheet extends StatefulWidget {
  final String memoryId;
  const RecordAudiographySheet({super.key, required this.memoryId});

  @override
  State<RecordAudiographySheet> createState() => _RecordAudiographySheetState();
}

enum _Stage { intro, recording, review }

class _RecordAudiographySheetState extends State<RecordAudiographySheet> {
  final _recorder = AudioRecorderService();
  final _authorController = TextEditingController();

  _Stage _stage = _Stage.intro;
  String? _recordedRef;
  String? _emotion;
  DateTime? _startedAt;
  int _durationMs = 0;
  bool _busy = false;

  @override
  void dispose() {
    _authorController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _snack('Necesitamos permiso para usar el micrófono.');
      return;
    }
    await _recorder.startRecording();
    setState(() {
      _stage = _Stage.recording;
      _startedAt = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    final ref = await _recorder.stopAndSave();
    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    if (ref == null) {
      _snack('No se pudo guardar la grabación. Inténtalo de nuevo.');
      setState(() => _stage = _Stage.intro);
      return;
    }
    setState(() {
      _recordedRef = ref;
      _durationMs = elapsed;
      _stage = _Stage.review;
    });
  }

  Future<void> _save() async {
    final author = _authorController.text.trim();
    if (_recordedRef == null || author.isEmpty) return;

    setState(() => _busy = true);
    await context.read<MemoryProvider>().addAudiography(
          memoryId: widget.memoryId,
          audioPath: _recordedRef!,
          authorName: author,
          emotionTag: _emotion,
          durationMs: _durationMs,
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          switch (_stage) {
            _Stage.intro => _buildIntro(),
            _Stage.recording => _buildRecording(),
            _Stage.review => _buildReview(),
          },
        ],
      ),
    );
  }

  Widget _buildIntro() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Añadir audiografía', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            AppConstants.audioTermsShort,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _startRecording,
          icon: const Icon(Icons.mic, size: 28),
          label: const Text('Aceptar y grabar'),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              StreamBuilder(
                stream: _recorder.amplitudeStream(),
                builder: (context, _) => Icon(
                  Icons.mic,
                  size: 72,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              Text('Grabando…', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _stopRecording,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          icon: const Icon(Icons.stop, size: 28),
          label: const Text('Detener'),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Casi listo', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _authorController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 19),
          decoration: const InputDecoration(
            labelText: '¿Quién grabó esto?',
            hintText: 'Ej. Carlos, tu hijo',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text('Emoción', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.emotionTags.map((tag) {
            final selected = _emotion == tag;
            return ChoiceChip(
              label: Text(tag, style: const TextStyle(fontSize: 16)),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _emotion = selected ? null : tag),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _authorController.text.trim().isEmpty || _busy
              ? null
              : _save,
          icon: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check),
          label: Text(_busy ? 'Guardando…' : 'Guardar audiografía'),
        ),
      ],
    );
  }
}
