import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../../core/app_copy.dart';
import '../../core/emotions.dart';
import '../../core/profile.dart';
import '../../data/media/media_store.dart';
import '../../data/models/audiography.dart';
import '../../data/models/person.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/audio_dial.dart';
import '../../design/components/app_glass.dart';
import '../../design/components/app_text.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import '../../state/profile_store.dart';
import '../../utils/time_ago.dart';
import '../activities/fog_reveal_screen.dart';
import '../activities/play_memory_screen.dart';
import '../feed/feed_screen.dart';
import '../record/record_audiography_sheet.dart';

/// Modo paciente: UN recuerdo a la vez, a pantalla completa. El fondo es la
/// propia foto desenfocada (ambiente), la foto nítida flota encima, y la voz
/// querida se reproduce sola. Todo con cristal y el color de la foto.
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
  Profile _profile = const Profile();
  List<Person> _people = const [];
  AppCopy _copy = const AppCopy(Profile());
  final _rand = Random();
  bool _invite = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  static (String, String) _split(String author) {
    final parts = author.split(',');
    final name = parts.first.trim();
    final rel = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    return (name.isEmpty ? author.trim() : name, rel);
  }

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

  void _onMemoryShown(MemoryWithAudios m) {
    _extractColor(m.memory.photoPath);
    if (m.audios.isNotEmpty) {
      // En web se carga sin arrancar (el navegador bloquea el autoplay sin
      // gesto); el primer toque de play lo inicia. En móvil arranca solo.
      _player.playSequence(m.audios.map((a) => a.audioPath).toList(),
          autostart: !kIsWeb);
    } else {
      _player.stop();
    }
    // De vez en cuando, invita a jugar con este recuerdo (sin obligar).
    if (_rand.nextInt(3) == 0) {
      setState(() => _invite = true);
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (mounted) setState(() => _invite = false);
      });
    } else {
      _invite = false;
    }
  }

  void _openGame(MemoryWithAudios m) {
    _player.stop();
    final feed = context.read<MemoryProvider>().feed;
    // Si el recuerdo tiene con qué preguntar (voces, o falta la descripción),
    // "La niebla que se despeja"; si no, el rompecabezas de la foto.
    final fogMaterial = m.audios.isNotEmpty ||
        (m.memory.description?.trim().isEmpty ?? true);
    final Widget game = fogMaterial
        ? FogRevealScreen(item: m, feed: feed)
        : PlayMemoryScreen(item: m);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => game));
  }

  Future<void> _extractColor(String ref) async {
    try {
      final provider = await Media.store.imageProvider(ref);
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(200, 200),
        maximumColorCount: 8,
      );
      final base = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (base == null || !mounted) return;
      final hsl = HSLColor.fromColor(base);
      setState(() {
        _amb = hsl
            .withSaturation((hsl.saturation + 0.1).clamp(0.4, 1.0))
            .withLightness(hsl.lightness.clamp(0.45, 0.62))
            .toColor();
        _amb2 = hsl.withLightness((hsl.lightness - 0.22).clamp(0.2, 0.5)).toColor();
      });
    } catch (_) {}
  }

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

  /// El dial pidió ir a la voz [i] del recuerdo: cárgalo (si hace falta) y salta.
  Future<void> _seekAudio(MemoryWithAudios m, int i) async {
    if (i < 0 || i >= m.audios.length) return;
    if (!_playingThisMemory(m)) {
      await _player.playSequence(m.audios.map((a) => a.audioPath).toList());
    }
    await _player.skipTo(i);
  }

  /// Añade una nueva voz a ESTE recuerdo (las audiografías se acumulan con el
  /// tiempo). Abre la grabación; al guardar, el feed se refresca y aparece una
  /// burbuja más alrededor de la foto.
  Future<void> _addVoice(MemoryWithAudios m) async {
    _player.stop();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RecordAudiographySheet(memoryId: m.memory.id),
    );
  }

  /// Retrato de la persona cuyo nombre coincide con el autor (para la burbuja).
  Person? _personFor(String author) {
    final target = _split(author).$1.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final p in _people) {
      if (p.hasPortrait && p.name.trim().toLowerCase() == target) return p;
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final feed = provider.feed;
    _people = provider.people;
    _profile = context.watch<ProfileStore>().profile;
    _copy = AppCopy(_profile);

    if (provider.loading && feed.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (feed.isEmpty) return _empty();

    final index = _index.clamp(0, feed.length - 1);
    final m = feed[index];

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
          // Fondo: la propia foto, desenfocada y ampliada.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.clamp),
            child: Transform.scale(
              scale: 1.2,
              child: RefImage(m.memory.photoPath, fit: BoxFit.cover),
            ),
          ),
          // Oscurecido + brillo de ambiente (color de la foto).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.7),
                radius: 1.3,
                colors: [
                  _amb.withValues(alpha: 0.28),
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                children: [
                  _topBar(),
                  const SizedBox(height: AppSpace.md),
                  Expanded(child: Center(child: _hero(m))),
                  const SizedBox(height: AppSpace.lg),
                  _playControl(m),
                  const SizedBox(height: AppSpace.lg),
                  _nameplate(m),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Jugar',
                          icon: Icons.extension_rounded,
                          variant: AppButtonVariant.glass,
                          onPressed: () => _openGame(m),
                        ),
                      ),
                      if (feed.length > 1) ...[
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: AppButton(
                            label: _copy.otherMemory,
                            icon: Icons.arrow_forward_rounded,
                            variant: AppButtonVariant.glass,
                            onPressed: () => _next(feed.length),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Invitación animada a jugar con este recuerdo.
          Positioned(
            left: 20,
            right: 20,
            top: 78,
            child: IgnorePointer(
              ignoring: !_invite,
              child: AnimatedSlide(
                offset: _invite ? Offset.zero : const Offset(0, -1.4),
                duration: AppMotion.base,
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _invite ? 1 : 0,
                  duration: AppMotion.base,
                  child: _inviteBanner(m),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteBanner(MemoryWithAudios m) {
    return GestureDetector(
      onTap: () {
        setState(() => _invite = false);
        _openGame(m);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(colors: [
                _amb.withValues(alpha: 0.55),
                _amb2.withValues(alpha: 0.55),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: const Row(
              children: [
                Text('🧩', style: TextStyle(fontSize: 26)),
                SizedBox(width: 12),
                Expanded(
                  child: AppText('¡Juguemos con este recuerdo!',
                      variant: AppTextVariant.bodyStrong, tone: AppTone.onPhoto),
                ),
                Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 30),
              ],
            ),
          ),
        ),
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
              AppText(_copy.greeting(_greeting),
                  variant: AppTextVariant.titleM, tone: AppTone.onPhoto),
              AppText(_copy.momentSubtitle,
                  variant: AppTextVariant.caption, tone: AppTone.onPhoto),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Para quienes te quieren',
          child: GestureDetector(
            onTap: _openCaregiver,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 10),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/senss_icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // La foto nítida "flota" sobre su versión desenfocada, rodeada por las voces.
  Widget _hero(MemoryWithAudios m) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;
        // Encaja una tarjeta 4:5 dentro del espacio disponible.
        var cardW = w;
        var cardH = cardW * 5 / 4;
        if (cardH > h) {
          cardH = h;
          cardW = cardH * 4 / 5;
        }
        final card = Container(
          width: cardW,
          height: cardH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: _amb.withValues(alpha: 0.45),
                blurRadius: 60,
                spreadRadius: -6,
              ),
              const BoxShadow(
                color: Color(0x99000000),
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RefImage(m.memory.photoPath, fit: BoxFit.cover),
              // Título sobre un degradado inferior.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                    stops: [0.55, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: AppText(m.memory.title,
                    variant: AppTextVariant.titleL,
                    tone: AppTone.onPhoto,
                    maxLines: 2),
              ),
            ],
          ),
        );

        // Las burbujas se resaltan según la voz activa (cambia al girar el dial).
        return SizedBox(
          width: cardW,
          height: cardH,
          child: AnimatedBuilder(
            animation: _player,
            builder: (context, _) {
              final active = _activeAudio(m);
              final activeIndex = active == null
                  ? -1
                  : m.audios.indexOf(active).clamp(0, m.audios.length - 1);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  card,
                  ..._voiceBubbles(m, cardW, cardH, activeIndex),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Anillo de burbujas alrededor de la foto: una por voz + una "+" para añadir.
  /// Se distribuyen en un arco superior (deja libre el pie, donde va el título).
  List<Widget> _voiceBubbles(
      MemoryWithAudios m, double cardW, double cardH, int activeIndex) {
    final voices = m.audios.length;
    final showVoices = voices >= 1 && voices <= 8;
    final slots = (showVoices ? voices : 0) + 1; // +1 = burbuja de añadir.
    final base = (cardW * 0.17).clamp(42.0, 66.0);
    final rx = cardW * 0.42;
    final ry = cardH * 0.42;
    final cx = cardW / 2;
    final cy = cardH / 2;
    const used = 2 * pi * (240 / 360); // arco de 240°, libre el pie (título).

    Offset at(int i) {
      final frac = slots == 1 ? 0.5 : i / (slots - 1);
      final ang = (-pi / 2 - used / 2) + used * frac;
      return Offset(cx + rx * cos(ang), cy + ry * sin(ang));
    }

    final result = <Widget>[];
    Widget? activeBubble;
    if (showVoices) {
      for (var i = 0; i < voices; i++) {
        final isActive = i == activeIndex;
        final size = isActive ? base * 1.32 : base;
        final c = at(i);
        final w = Positioned(
          left: c.dx - size / 2,
          top: c.dy - size / 2,
          child: _voiceBubble(m, i, m.audios[i], isActive, size),
        );
        if (isActive) {
          activeBubble = w;
        } else {
          result.add(w);
        }
      }
    }
    // Burbuja de añadir (siempre): último slot del arco.
    final c = at(slots - 1);
    result.add(Positioned(
      left: c.dx - base / 2,
      top: c.dy - base / 2,
      child: _addBubble(m, base),
    ));
    if (activeBubble != null) result.add(activeBubble); // activa, encima.
    return result;
  }

  Widget _voiceBubble(
      MemoryWithAudios m, int index, Audiography a, bool isActive, double size) {
    final person = _personFor(a.authorName);
    final (n, _) = _split(a.authorName);
    final s = EmotionStyle.of(a.emotionTag);
    return Semantics(
      button: true,
      label: 'Voz de $n',
      child: GestureDetector(
        onTap: () => _seekAudio(m, index),
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: person == null
                ? LinearGradient(colors: [_amb, _amb2])
                : null,
            border: Border.all(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
              width: isActive ? 3 : 2,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                    color: _amb.withValues(alpha: 0.7),
                    blurRadius: 20,
                    spreadRadius: 1),
              const BoxShadow(color: Color(0x66000000), blurRadius: 8),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (person != null)
                RefImage(person.portraitPath, fit: BoxFit.cover)
              else
                Center(
                  child: AppText(
                    n.isEmpty ? '♪' : n.substring(0, 1).toUpperCase(),
                    variant: AppTextVariant.titleM,
                    color: Colors.white,
                  ),
                ),
              if (isActive)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(s.emoji, style: TextStyle(fontSize: size * 0.3)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addBubble(MemoryWithAudios m, double size) {
    return Semantics(
      button: true,
      label: 'Añadir una voz a este recuerdo',
      child: GestureDetector(
        onTap: () => _addVoice(m),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_amb.withValues(alpha: 0.9), _amb2.withValues(alpha: 0.9)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: Icon(Icons.add_rounded, color: Colors.white, size: size * 0.56),
        ),
      ),
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
        final activeIndex =
            active == null ? 0 : m.audios.indexOf(active).clamp(0, m.audios.length - 1);
        final name = active != null ? _split(active.authorName).$1 : '';

        return Column(
          children: [
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, pSnap) {
                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, dSnap) {
                    final pos = pSnap.data ?? Duration.zero;
                    final total = dSnap.data ?? Duration.zero;
                    final progress = (playingHere && total.inMilliseconds > 0)
                        ? (pos.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return AudioDial(
                      count: m.audios.length,
                      index: activeIndex,
                      playing: isPlaying,
                      progress: progress,
                      color: _amb,
                      color2: _amb2,
                      scale: _profile.iconScale,
                      enabled: hasVoices,
                      onPlayPause: () => _togglePlay(m),
                      onSeek: (i) => _seekAudio(m, i),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpace.md),
            AppText(
              hasVoices
                  ? (isPlaying
                      ? _copy.nowPlaying(name)
                      : _copy.playHint(name))
                  : _copy.noVoices,
              variant: AppTextVariant.bodyStrong,
              tone: AppTone.onPhoto,
              align: TextAlign.center,
            ),
            if (hasVoices && m.audios.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AppText(
                  'Voz ${activeIndex + 1} de ${m.audios.length} · gira para escuchar',
                  variant: AppTextVariant.caption,
                  tone: AppTone.onPhoto,
                  align: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _nameplate(MemoryWithAudios m) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) {
        final a = _activeAudio(m);
        if (a == null) return const SizedBox.shrink();
        final (n, r) = _split(a.authorName);
        final s = EmotionStyle.of(a.emotionTag);
        return AppGlass(
          tint: _amb.withValues(alpha: 0.20),
          borderColor: Colors.white.withValues(alpha: 0.22),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
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
                  Text(s.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 2),
                  AppText(TimeAgo.short(a.createdAt),
                      variant: AppTextVariant.caption, tone: AppTone.onPhoto),
                ],
              ),
            ],
          ),
        );
      },
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
                AppText(_copy.emptyTitle,
                    variant: AppTextVariant.titleL,
                    tone: AppTone.onPhoto,
                    align: TextAlign.center),
                const SizedBox(height: AppSpace.md),
                AppText(
                  _copy.emptyBody,
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

