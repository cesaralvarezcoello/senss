import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/audiography.dart';
import '../../state/memory_provider.dart';

/// Hoja inferior para editar los metadatos de una audiografía ya grabada:
/// quién la grabó y la emoción. El archivo de audio no se modifica.
class EditAudiographySheet extends StatefulWidget {
  final Audiography audio;
  const EditAudiographySheet({super.key, required this.audio});

  @override
  State<EditAudiographySheet> createState() => _EditAudiographySheetState();
}

class _EditAudiographySheetState extends State<EditAudiographySheet> {
  late final TextEditingController _authorController;
  String? _emotion;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _authorController = TextEditingController(text: widget.audio.authorName);
    _emotion = widget.audio.emotionTag;
  }

  @override
  void dispose() {
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final author = _authorController.text.trim();
    if (author.isEmpty) return;

    setState(() => _busy = true);
    await context.read<MemoryProvider>().editAudiography(
          audio: widget.audio,
          authorName: author,
          emotionTag: _emotion,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text('Editar audiografía', style: theme.textTheme.titleLarge),
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
            onPressed:
                _authorController.text.trim().isEmpty || _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
