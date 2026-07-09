import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/memory_repository.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/app_card.dart';
import '../../../design/components/app_text.dart';
import '../../../design/components/voice_bubble.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../state/memory_provider.dart';
import '../../../utils/time_ago.dart';
import '../../record/record_audiography_sheet.dart';

/// Tarjeta de un recuerdo: la foto es la protagonista y las audiografías viven
/// "dentro" de ella como burbujas de voz. Debajo, la descripción y la acción
/// para añadir una voz nueva.
class MemoryCard extends StatelessWidget {
  final MemoryWithAudios item;
  final AudioPlayerService player;

  const MemoryCard({super.key, required this.item, required this.player});

  Future<void> _addVoice(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecordAudiographySheet(memoryId: item.memory.id),
    );
  }

  Future<void> _playAll() async {
    await player.playSequence(item.audios.map((a) => a.audioPath).toList());
  }

  Future<void> _confirmDeleteMemory(BuildContext context) async {
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
    if (ok == true) await provider.deleteMemory(item.memory);
  }

  @override
  Widget build(BuildContext context) {
    final memory = item.memory;
    final audios = item.audios;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Foto protagonista con las voces dentro ---
          GestureDetector(
            onLongPress: () => _confirmDeleteMemory(context),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(memory.photoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: context.colors.surfaceSoft,
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: context.colors.inkFaint),
                    ),
                  ),
                  // Velo para legibilidad arriba (título) y abajo (voces).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x73000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xA6000000),
                        ],
                        stops: [0.0, 0.26, 0.52, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  // Título + fecha (arriba, izq.) y "Reproducir todo" (arriba, der.).
                  Positioned(
                    top: 16,
                    left: 18,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(memory.title,
                                  variant: AppTextVariant.titleL,
                                  tone: AppTone.onPhoto,
                                  maxLines: 2),
                              const SizedBox(height: 2),
                              AppText(TimeAgo.fullDate(memory.createdAt),
                                  variant: AppTextVariant.caption,
                                  tone: AppTone.onPhoto),
                            ],
                          ),
                        ),
                        if (audios.length > 1)
                          _PlayAllPill(onTap: _playAll),
                      ],
                    ),
                  ),
                  // Voces dentro de la foto (o invitación si no hay).
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: audios.isEmpty
                        ? const _EmptyVoicesHint()
                        : SizedBox(
                            height: 118,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              itemCount: audios.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpace.md),
                              itemBuilder: (_, i) => VoiceBubble(
                                audio: audios[i],
                                player: player,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // --- Cuerpo: descripción + añadir voz ---
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memory.description != null) ...[
                  AppText(memory.description!, variant: AppTextVariant.body),
                  const SizedBox(height: AppSpace.lg),
                ],
                AppButton(
                  label: 'Añadir una voz',
                  icon: Icons.mic_none_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => _addVoice(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayAllPill extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayAllPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC0E0B09),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_play_rounded, size: 20, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Todo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyVoicesHint extends StatelessWidget {
  const _EmptyVoicesHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: AppText(
        'Aún no hay voces. Añade la primera 💛',
        variant: AppTextVariant.bodyStrong,
        tone: AppTone.onPhoto,
      ),
    );
  }
}
