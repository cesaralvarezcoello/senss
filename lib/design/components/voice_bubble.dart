import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/emotions.dart';
import '../../data/models/audiography.dart';
import '../../data/services/audio_player_service.dart';
import '../../features/record/edit_audiography_sheet.dart';
import '../../state/memory_provider.dart';
import '../../utils/time_ago.dart';
import '../tokens.dart';
import '../typography.dart';
import 'app_text.dart';

/// Burbuja de voz: representa una audiografía "dentro" del recuerdo, como un
/// anillo con el color de su emoción y la inicial de quien la grabó. Al
/// reproducirse, el anillo se convierte en una barra de progreso circular.
/// Toca para reproducir/pausar; mantén pulsado para editar o eliminar.
class VoiceBubble extends StatelessWidget {
  final Audiography audio;
  final AudioPlayerService player;
  final double size;

  const VoiceBubble({
    super.key,
    required this.audio,
    required this.player,
    this.size = 68,
  });

  String get _firstName {
    final n = audio.authorName.split(',').first.trim();
    return n.isEmpty ? audio.authorName.trim() : n;
  }

  String get _initial =>
      _firstName.isEmpty ? '♪' : _firstName.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final style = EmotionStyle.of(audio.emotionTag);

    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final isCurrent = player.isCurrent(audio.audioPath);
        final isPlaying = isCurrent && player.isPlaying;

        return Semantics(
          button: true,
          label: 'Audiografía de $_firstName. '
              '${isPlaying ? 'Reproduciendo. Toca para pausar.' : 'Toca para reproducir.'}',
          child: GestureDetector(
            onTap: () => _toggle(isCurrent, isPlaying),
            onLongPress: () => _showActions(context),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: size + 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isCurrent ? 1.06 : 1.0,
                    duration: AppMotion.base,
                    curve: AppMotion.curve,
                    child: _ring(style.color, isCurrent, isPlaying),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '${style.emoji} $_firstName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Color(0xB3000000), blurRadius: 8),
                      ],
                    ),
                  ),
                  Text(
                    TimeAgo.short(audio.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      shadows: const [
                        Shadow(color: Color(0xB3000000), blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ring(Color color, bool isCurrent, bool isPlaying) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillo estático o progreso de reproducción.
          SizedBox(
            width: size,
            height: size,
            child: isCurrent
                ? _progressRing(color)
                : CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 4.5,
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.55)),
                    backgroundColor: color.withValues(alpha: 0.18),
                  ),
          ),
          // Avatar con la inicial.
          Container(
            width: size - 12,
            height: size - 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  HSLColor.fromColor(color)
                      .withLightness(
                          (HSLColor.fromColor(color).lightness - 0.12).clamp(0.0, 1.0))
                      .toColor(),
                ],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: AppType.titleM.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
            ),
          ),
          // Insignia de estado (play/pausa).
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xF20E0B09),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRing(Color color) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, dSnap) {
        final total = dSnap.data ?? Duration(milliseconds: audio.durationMs);
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, pSnap) {
            final pos = pSnap.data ?? Duration.zero;
            final maxMs = total.inMilliseconds;
            final value =
                maxMs <= 0 ? null : (pos.inMilliseconds / maxMs).clamp(0.0, 1.0);
            return CircularProgressIndicator(
              value: value,
              strokeWidth: 4.5,
              valueColor: AlwaysStoppedAnimation(color),
              backgroundColor: color.withValues(alpha: 0.22),
            );
          },
        );
      },
    );
  }

  Future<void> _toggle(bool isCurrent, bool isPlaying) async {
    if (isPlaying) {
      await player.pause();
    } else if (isCurrent) {
      await player.resume();
    } else {
      await player.playFile(audio.audioPath);
    }
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpace.sm),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppText('Audiografía de $_firstName',
                    variant: AppTextVariant.titleM),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: ctx.colors.ink),
              title: const AppText('Editar'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: ctx.colors.danger),
              title: const AppText('Eliminar', tone: AppTone.danger),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'edit') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => EditAudiographySheet(audio: audio),
      );
    } else if (action == 'delete') {
      await _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<MemoryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar audiografía?'),
        content: Text(
          'Se borrará esta voz de $_firstName de este dispositivo. '
          'No se puede deshacer.',
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
      if (player.isCurrent(audio.audioPath)) await player.stop();
      await provider.deleteAudiography(audio);
    }
  }
}
