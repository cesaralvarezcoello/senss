import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/memory_repository.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../state/memory_provider.dart';
import '../../../utils/time_ago.dart';
import '../../record/record_audiography_sheet.dart';
import 'audiography_tile.dart';

/// Tarjeta de un recuerdo en el feed: foto grande arriba, información del
/// recuerdo, la lista de audiografías y un botón grande para añadir audio.
class MemoryCard extends StatelessWidget {
  final MemoryWithAudios item;
  final AudioPlayerService player;

  const MemoryCard({super.key, required this.item, required this.player});

  Future<void> _addAudiography(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecordAudiographySheet(memoryId: item.memory.id),
    );
  }

  Future<void> _playAll() async {
    final paths = item.audios.map((a) => a.audioPath).toList();
    await player.playSequence(paths);
  }

  @override
  Widget build(BuildContext context) {
    final memory = item.memory;
    final audios = item.audios;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Foto principal (estilo feed) ---
          AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              File(memory.photoPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE0E0E0),
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memory.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  TimeAgo.fullDate(memory.createdAt),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                if (memory.description != null) ...[
                  const SizedBox(height: 8),
                  Text(memory.description!, style: theme.textTheme.bodyLarge),
                ],
              ],
            ),
          ),

          // --- Lista de audiografías (el hilo de audio-recuerdos) ---
          if (audios.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Audiografías (${audios.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (audios.length > 1)
                    TextButton.icon(
                      onPressed: _playAll,
                      icon: const Icon(Icons.playlist_play, size: 26),
                      label: const Text('Reproducir todo'),
                    ),
                ],
              ),
            ),
            ...audios.map(
              (audio) => AudiographyTile(audio: audio, player: player),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Todavía no hay audiografías para este recuerdo.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),

          // --- Botón grande y accesible para añadir audio ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.tonalIcon(
              onPressed: () => _addAudiography(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
              ),
              icon: const Icon(Icons.mic, size: 28),
              label: const Text(
                'Añadir audiografía',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menú contextual opcional para eliminar un recuerdo (mantener presionado).
extension MemoryCardActions on MemoryCard {
  Future<void> confirmDelete(BuildContext context) async {
    final provider = context.read<MemoryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar recuerdo?'),
        content: const Text(
          'Se borrará la foto y todas sus audiografías de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.deleteMemory(item.memory);
    }
  }
}
