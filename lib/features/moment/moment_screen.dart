import 'dart:io';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../../core/emotions.dart';
import '../../data/models/audiography.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_glass.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import '../../utils/time_ago.dart';
import '../feed/feed_screen.dart';

/// Pantalla principal (modo paciente): UN recuerdo a la vez, a pantalla
/// completa. La voz de quien amas se reproduce sola; un solo botón enorme.
/// Le recuerda quién es y cuándo fue. El color de la foto tiñe todo el ambiente.
class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key});

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen> {
  final AudioPlayerService _player = AudioPlayerService();

  int _index = 0;
  String? _shownId;
  Color _amb = const Color(0xFFE08A2E);
  Color _amb2 = const Color(0xFFC7562F);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ---- Datos derivados ----

  /// Divide "Carlos, tu hijo" en nombre y relación.
  static (String, String) _split(String author) {
    final parts = author.split(',');
    final name = parts.first.trim();
    final rel = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    return (name.isEmpty ? author.trim() : name, rel);
  }

  /// Audiografía "activa": la que suena ahora (si es de este recuerdo) o la
  /// primera del recuerdo.
  Audiography? _activeAudio(MemoryWithAudios m) {
    if (m.audios.isEmpty) return null;
    final path = _player.currentPath;
    if (path != null) {
      for (final a in m.audios) {
        if (a.audioPath == path) return a;
      }
    }
    return m.audios.first;
  }

  bool _playingThisMemory(MemoryWithAudios m) {
    final path = _player.currentPath;
    return path != null && m.audios.any((a) => a.audioPath == path);
  }

  // ---- Efectos al mostrar un recuerdo ----

  void _onMemoryShown(MemoryWithAudios m) {
    _extractColor(m.memory.photoPath);
    // Reproduce las voces del recuerdo automáticamente (la magia: toca... o ni
    // eso: suena solo al abrir).
    if (m.audios.isNotEmpty) {
      _player.playSequence(m.audios.map((a) => a.audioPath).toList());
    } else {
      _player.stop();
    }
  }

  Future<void> _extractColor(String photoPath) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(File(photoPath)),
        size: const Size(220, 220),
        maximumColorCount: 8,
      );
      final base = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (base == null || !mounted) return;
      final hsl = HSLColor.fromColor(base);
      // Sube saturación y controla luminosidad para un ambiente cálido.
      final amb = hsl
          .withSaturation((hsl.saturation + 0.1).clamp(0.35, 1.0))
          .withLightness(hsl.lightness.clamp(0.45, 0.62))
          .toColor();
      final amb2 = hsl
          .withLightness((hsl.lightness - 0.2).clamp(0.2, 0.5))
          .toColor();
      setState(() {
        _amb = amb;
        _amb2 = amb2;
      });
    } catch (_) {
      // Si falla, se queda el ambiente por defecto.
    }
  }

  // ---- Navegación / control ----

  void _next(int length) {
    _player.stop();
    setState(() => _index = (_index + 1) % length);
  }

  void _togglePlay(MemoryWithAudios m) {
    if (m.audios.isEmpty) return;
    if (_player.isPlaying) {
      _player.pause();
    } else if (_playingThisMemory(m)) {
      _player.resume();
    } else {
      _player.playSequence(m.audios.map((a) => a.audioPath).toList());
    }
  }

  Future<void> _openCaregiver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modo familia'),
        content: const Text(
          'Aquí la familia añade recuerdos, graba voces y gestiona la copia de '
          'seguridad. ¿Quieres entrar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _player.stop();
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FeedScreen()),
      );
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final feed = provider.feed;

    if (provider.loading && feed.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.isEmpty) return _empty();

    final index = _index.clamp(0, feed.length - 1);
    final m = feed[index];

    // Al cambiar de recuerdo: extrae color y reproduce.
    if (m.memory.id != _shownId) {
      _shownId = m.memory.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onMemoryShown(m);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Foto a pantalla completa (con transición suave entre recuerdos).
          AnimatedSwitcher(
            duration: AppMotion.slow,
            child: Image.file(
              File(m.memory.photoPath),
              key: ValueKey(m.memory.id),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF1A1410)),
            ),
          ),
          // Velo para legibilidad.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Color(0x00000000), Color(0x00000000), Color(0xE0000000)],
                stops: [0.0, 0.22, 0.42, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Brillo de ambiente (color de la foto) arriba.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.1,
                  colors: [_amb.withValues(alpha: 0.34), Colors.transparent],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  _topBar(),
                  const Spacer(),
                  _playControl(m),
                  const Spacer(),
                  _bottom(m, feed.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(_greeting,
                  variant: AppTextVariant.titleM, tone: AppTone.onPhoto),
              const AppText('Un recuerdo para ti',
                  variant: AppTextVariant.caption, tone: AppTone.onPhoto),
            ],
          ),
        ),
        // Acceso discreto y gateado al modo familia (mantener pulsado).
        Semantics(
          button: true,
          label: 'Para la familia. Mantén pulsado para entrar.',
          child: GestureDetector(
            onLongPress: _openCaregiver,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Icon(Icons.more_horiz, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playControl(MemoryWithAudios m) {
    final hasVoices = m.audios.isNotEmpty;
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final playingHere = _playingThisMemory(m);
        final isPlaying = playingHere && _player.isPlaying;
        final active = _activeAudio(m);
        final name = active != null ? _split(active.authorName).$1 : '';

        return Column(
          children: [
            GestureDetector(
              onTap: hasVoices ? () => _togglePlay(m) : null,
              child: SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (playingHere)
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: _ProgressRing(player: _player, color: _amb),
                      )
                    else
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation(
                              Colors.white.withValues(alpha: hasVoices ? 0.28 : 0.14)),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hasVoices
                              ? [_amb, _amb2]
                              : [const Color(0xFF4A423B), const Color(0xFF2C2622)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _amb.withValues(alpha: hasVoices ? 0.5 : 0.0),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 66,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppText(
              hasVoices
                  ? (isPlaying
                      ? 'Escuchando a $name…'
                      : 'Toca para escuchar${name.isEmpty ? '' : ' a $name'}')
                  : 'Aún no hay voces en este recuerdo',
              variant: AppTextVariant.bodyStrong,
              tone: AppTone.onPhoto,
              align: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _bottom(MemoryWithAudios m, int total) {
    final active = _activeAudio(m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El "momento": título grande.
        AppText(
          m.memory.title,
          variant: AppTextVariant.display,
          tone: AppTone.onPhoto,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpace.md),
        // Placa de cristal: quién es y cuándo (orientación).
        if (active != null)
          AnimatedBuilder(
            animation: _player,
            builder: (context, _) {
              final a = _activeAudio(m) ?? active;
              final (n, r) = _split(a.authorName);
              final s = EmotionStyle.of(a.emotionTag);
              return AppGlass(
                tint: _amb.withValues(alpha: 0.18),
                borderColor: Colors.white.withValues(alpha: 0.22),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_amb, _amb2]),
                      ),
                      alignment: Alignment.center,
                      child: AppText(
                        n.isEmpty ? '♪' : n.substring(0, 1).toUpperCase(),
                        variant: AppTextVariant.titleM,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(n,
                              variant: AppTextVariant.titleM,
                              tone: AppTone.onPhoto,
                              maxLines: 1),
                          if (r.isNotEmpty)
                            AppText(r,
                                variant: AppTextVariant.caption,
                                tone: AppTone.onPhoto,
                                maxLines: 1),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${s.emoji}', style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 2),
                        AppText(TimeAgo.short(a.createdAt),
                            variant: AppTextVariant.caption,
                            tone: AppTone.onPhoto),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: AppSpace.md),
        // Un solo control: otro recuerdo.
        if (total > 1)
          AppGlass(
            radius: AppRadius.lg,
            tint: Colors.white.withValues(alpha: 0.10),
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _next(total),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText('Otro recuerdo',
                          variant: AppTextVariant.label, tone: AppTone.onPhoto),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty() {
    return Scaffold(
      backgroundColor: const Color(0xFF14100D),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded,
                    size: 72, color: _amb.withValues(alpha: 0.9)),
                const SizedBox(height: AppSpace.xl),
                const AppText('Aún no hay recuerdos',
                    variant: AppTextVariant.titleL,
                    tone: AppTone.onPhoto,
                    align: TextAlign.center),
                const SizedBox(height: AppSpace.md),
                const AppText(
                  'La familia puede añadir la primera foto y grabarle una voz.',
                  variant: AppTextVariant.body,
                  tone: AppTone.onPhoto,
                  align: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.xl),
                AppButton(
                  label: 'Entrar como familia',
                  icon: Icons.family_restroom_rounded,
                  expand: false,
                  onPressed: _openCaregiver,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo de progreso alrededor del botón de reproducir (sigue a la voz).
class _ProgressRing extends StatelessWidget {
  final AudioPlayerService player;
  final Color color;
  const _ProgressRing({required this.player, required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, dSnap) {
        final total = dSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, pSnap) {
            final pos = pSnap.data ?? Duration.zero;
            final maxMs = total.inMilliseconds;
            final value =
                maxMs <= 0 ? null : (pos.inMilliseconds / maxMs).clamp(0.0, 1.0);
            return CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(color),
              backgroundColor: Colors.white.withValues(alpha: 0.14),
            );
          },
        );
      },
    );
  }
}
