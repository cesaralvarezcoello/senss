import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';

/// Bienvenida sentimental y **visual primero** (imágenes sobre texto, ideal
/// para personas con Alzheimer). Escenas pintadas y animadas; en el corazón,
/// una página donde se **siente** el poder de una voz (onda que late + sonido).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _anim;
  final _player = AudioPlayer();
  Uint8List? _voice;
  bool _playing = false;
  int _page = 0;

  static const _last = 3;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _voice = _synthVoice();
    _player.playerStateStream.listen((s) {
      final p = s.playing && s.processingState != ProcessingState.completed;
      if (mounted && p != _playing) setState(() => _playing = p);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _player.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _hearVoice() async {
    if (_voice == null) return;
    try {
      await _player.stop();
      await _player.setAudioSource(
          AudioSource.uri(Uri.dataFromBytes(_voice!, mimeType: 'audio/wav')));
      await _player.play();
    } catch (_) {}
  }

  Future<void> _finish() async {
    await context.read<ProfileStore>().markOnboarded();
  }

  void _nextOrFinish() {
    if (_page < _last) {
      _pages.nextPage(duration: AppMotion.base, curve: AppMotion.curve);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0A07),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(painter: _OrbPainter(_anim.value)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _IllustrationPage(
                        anim: _anim,
                        image: 'assets/icon/senss_icon.png',
                        title: 'Tus recuerdos, a salvo',
                        subtitle: 'Solo tú los guardas, aquí en tu teléfono.',
                      ),
                      _IllustrationPage(
                        anim: _anim,
                        image: 'assets/images/onboarding/voices.png',
                        title: 'El poder de una voz',
                        subtitle: 'Tócala y escúchala.',
                        onTap: _hearVoice,
                        playing: _playing,
                      ),
                      _IllustrationPage(
                        anim: _anim,
                        image: 'assets/images/onboarding/connection.png',
                        title: 'Pide sus voces',
                        subtitle: 'Invita a quienes amas a dejar un recuerdo.',
                      ),
                      _IllustrationPage(
                        anim: _anim,
                        image: 'assets/images/onboarding/legacy.png',
                        title: 'Un tesoro para heredar',
                        subtitle: 'Toda una vida de recuerdos, guardada con amor.',
                      ),
                    ],
                  ),
                ),
                _dots(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: AppButton(
                    label: _page < _last ? 'Siguiente' : 'Comenzar',
                    icon: _page < _last
                        ? Icons.arrow_forward_rounded
                        : Icons.favorite_rounded,
                    onPressed: _nextOrFinish,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i <= _last; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _page ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }

  Uint8List _synthVoice() {
    const sr = 22050;
    const seconds = 4.0;
    final total = (seconds * sr).toInt();
    final notes = [220.0, 277.0, 330.0, 277.0];
    final noteLen = total ~/ notes.length;
    final data = ByteData(44 + total * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    final dataLen = total * 2;
    str(0, 'RIFF');
    data.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sr, Endian.little);
    data.setUint32(28, sr * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < total; i++) {
      final f = notes[(i ~/ noteLen).clamp(0, notes.length - 1)];
      final env = sin(pi * ((i % noteLen) / noteLen));
      final s = sin(2 * pi * f * i / sr) * env * 0.22;
      data.setInt16(44 + i * 2, (s * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

/// Página visual: una **ilustración** grande (la imagen manda) con un título
/// corto y un subtítulo breve. Si es interactiva (`onTap`), muestra ondas
/// alrededor de la tarjeta y una insignia de reproducción para escuchar una voz.
class _IllustrationPage extends StatelessWidget {
  final AnimationController anim;
  final String image;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool playing;
  const _IllustrationPage({
    required this.anim,
    required this.image,
    required this.title,
    this.subtitle,
    this.onTap,
    this.playing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (onTap != null)
                    AnimatedBuilder(
                      animation: anim,
                      builder: (_, __) => CustomPaint(
                        size: const Size(300, 300),
                        painter: _WavePainter(anim.value, playing),
                      ),
                    ),
                  // La foto como un objeto atesorado: marco cálido y sombra.
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55), width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 40,
                            offset: Offset(0, 18)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(image,
                          width: 264, height: 264, fit: BoxFit.cover),
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.34),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 2),
                      ),
                      child: Icon(
                          playing
                              ? Icons.graphic_eq_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          AppText(title,
              variant: AppTextVariant.display,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.sm),
            AppText(subtitle!,
                variant: AppTextVariant.body,
                tone: AppTone.onPhoto,
                align: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Ondas concéntricas que emanan alrededor de la tarjeta (más intensas al sonar).
class _WavePainter extends CustomPainter {
  final double t;
  final bool playing;
  _WavePainter(this.t, this.playing);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width * 0.46;
    for (var ring = 0; ring < 3; ring++) {
      final phase = (t + ring / 3) % 1;
      final r = base + phase * base * 0.4;
      final opacity = (1 - phase) * (playing ? 0.5 : 0.22);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFF0A344).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}

class _Orb {
  final double dx, dy, radius, speed, phase;
  final Color color;
  const _Orb(this.dx, this.dy, this.radius, this.color, this.speed, this.phase);
}

class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  static const _orbs = <_Orb>[
    _Orb(0.2, 0.25, 0.5, Color(0xFFE9A23B), 1.0, 0.0),
    _Orb(0.8, 0.2, 0.45, Color(0xFFC7562F), 0.8, 0.3),
    _Orb(0.75, 0.7, 0.5, Color(0xFF8E4EC6), 1.2, 0.6),
    _Orb(0.25, 0.75, 0.45, Color(0xFF3E63DD), 0.9, 0.2),
    _Orb(0.5, 0.5, 0.4, Color(0xFFE86A9B), 1.1, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in _orbs) {
      final cx =
          size.width * (o.dx + 0.05 * sin(t * 2 * pi * o.speed + o.phase * 6));
      final cy =
          size.height * (o.dy + 0.05 * cos(t * 2 * pi * o.speed + o.phase * 6));
      final radius = size.width * o.radius;
      final center = Offset(cx, cy);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [
            o.color.withValues(alpha: 0.35),
            o.color.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
