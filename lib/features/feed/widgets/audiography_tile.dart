import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/audiography.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../state/memory_provider.dart';
import '../../../utils/time_ago.dart';
import '../../record/edit_audiography_sheet.dart';

/// Una fila de audiografía: quién la grabó, hace cuánto, su emoción y un botón
/// grande de reproducir/pausar. Cuando es la pista activa se resalta y muestra
/// una barra de progreso para avanzar o retroceder.
class AudiographyTile extends StatelessWidget {
  final Audiography audio;
  final AudioPlayerService player;

  const AudiographyTile({
    super.key,
    required this.audio,
    required this.player,
  });

  Future<void> _edit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditAudiographySheet(audio: audio),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<MemoryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar audiografía?'),
        content: Text(
          'Se borrará esta nota de audio de ${audio.authorName} '
          'de este dispositivo. No se puede deshacer.',
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
      // Si esta pista está sonando, deténla antes de borrar el archivo.
      if (player.isCurrent(audio.audioPath)) await player.stop();
      await provider.deleteAudiography(audio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Se reconstruye cuando cambia la pista activa o el estado de reproducción.
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final isCurrent = player.isCurrent(audio.audioPath);
        final isPlaying = isCurrent && player.isPlaying;

        return Container(
          color: isCurrent ? theme.colorScheme.primaryContainer : null,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: _PlayButton(
                  isPlaying: isPlaying,
                  onPressed: () async {
                    if (isPlaying) {
                      await player.pause();
                    } else if (isCurrent) {
                      await player.resume();
                    } else {
                      await player.playFile(audio.audioPath);
                    }
                  },
                ),
                title: Text(
                  TimeAgo.sentence(audio.createdAt, audio.authorName),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(
                        TimeAgo.fullDate(audio.createdAt),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                      if (audio.emotionTag != null) ...[
                        const SizedBox(width: 8),
                        _EmotionChip(label: audio.emotionTag!),
                      ],
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 26),
                  tooltip: 'Opciones',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _edit(context);
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrubber solo bajo la fila que está sonando.
              if (isCurrent)
                _ProgressBar(player: player, fallbackMs: audio.durationMs),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final Future<void> Function() onPressed;
  const _PlayButton({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      iconSize: 32,
      padding: const EdgeInsets.all(8),
      onPressed: onPressed,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
    );
  }
}

/// Barra de progreso arrastrable de la pista activa, con tiempos legibles.
class _ProgressBar extends StatelessWidget {
  final AudioPlayerService player;

  /// Duración conocida de la grabación (ms), como reserva mientras `just_audio`
  /// no reporta todavía la duración real del archivo.
  final int fallbackMs;

  const _ProgressBar({required this.player, required this.fallbackMs});

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration(milliseconds: fallbackMs);
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            var position = posSnap.data ?? Duration.zero;
            if (position > total) position = total;
            final maxMs = total.inMilliseconds.toDouble();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxMs <= 0 ? 1 : maxMs,
                      value: position.inMilliseconds
                          .clamp(0, maxMs <= 0 ? 1 : maxMs)
                          .toDouble(),
                      onChanged: maxMs <= 0
                          ? null
                          : (v) => player
                              .seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(position),
                            style: theme.textTheme.bodyMedium),
                        Text(_fmt(total), style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmotionChip extends StatelessWidget {
  final String label;
  const _EmotionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }
}
