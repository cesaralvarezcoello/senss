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
                      _ScenePage(
                        title: 'Tus recuerdos, a salvo',
                        scene: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) => CustomPaint(
                            size: const Size(220, 220),
                            painter: _FramePainter(_anim.value),
                          ),
                        ),
                      ),
                      _voicePage(),
                      _ScenePage(
                        title: 'Toda una vida, en un lugar',
                        scene: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) => CustomPaint(
                            size: const Size(260, 220),
                            painter: _ConstellationPainter(_anim.value),
                          ),
                        ),
                      ),
                      _ScenePage(
                        title: 'Juntos, sin prisa',
                        scene: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) => CustomPaint(
                            size: const Size(240, 220),
                            painter: _HeartsPainter(_anim.value),
                          ),
                        ),
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

  Widget _voicePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _hearVoice,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => _VoiceOrb(t: _anim.value, playing: _playing),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          const AppText('Una voz que abraza',
              variant: AppTextVariant.display,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
          const SizedBox(height: AppSpace.sm),
          const AppText('Tócala y siéntelo',
              variant: AppTextVariant.body,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
        ],
      ),
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

/// Página visual: una escena grande arriba y un título corto abajo. Sin
/// párrafos: la imagen manda.
class _ScenePage extends StatelessWidget {
  final Widget scene;
  final String title;
  const _ScenePage({required this.scene, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          scene,
          const SizedBox(height: AppSpace.xxl),
          AppText(title,
              variant: AppTextVariant.display,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
        ],
      ),
    );
  }
}

// ------- Escenas pintadas -------

Path _heartPath(Size s) {
  final p = Path();
  p.moveTo(s.width * 0.5, s.height * 0.35);
  p.cubicTo(s.width * 0.2, -s.height * 0.02, -s.width * 0.25, s.height * 0.55,
      s.width * 0.5, s.height);
  p.cubicTo(s.width * 1.25, s.height * 0.55, s.width * 0.8, -s.height * 0.02,
      s.width * 0.5, s.height * 0.35);
  p.close();
  return p;
}

/// Escena 1: un marco de foto cálido con un corazón que late dentro.
class _FramePainter extends CustomPainter {
  final double t;
  _FramePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(size.width * 0.1, size.height * 0.08,
        size.width * 0.8, size.height * 0.84);
    // Foto (degradado cálido).
    final photo = RRect.fromRectAndRadius(r, const Radius.circular(22));
    canvas.drawRRect(
      photo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9A23B), Color(0xFFC7562F)],
        ).createShader(r),
    );
    // Marco.
    canvas.drawRRect(
      photo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    // Corazón que late.
    final pulse = 1 + 0.08 * sin(t * 2 * pi * 2);
    final hs = Size(size.width * 0.34 * pulse, size.height * 0.32 * pulse);
    canvas.save();
    canvas.translate(size.width * 0.5 - hs.width / 2,
        size.height * 0.44 - hs.height / 2);
    canvas.drawPath(
      _heartPath(hs),
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter old) => true;
}

/// Escena 3: una constelación de recuerdos a lo largo de una vida.
class _ConstellationPainter extends CustomPainter {
  final double t;
  _ConstellationPainter(this.t);

  static const _pts = <Offset>[
    Offset(0.1, 0.7), Offset(0.28, 0.4), Offset(0.45, 0.62),
    Offset(0.6, 0.3), Offset(0.75, 0.55), Offset(0.9, 0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(int i) => Offset(_pts[i].dx * size.width, _pts[i].dy * size.height);
    // Hilo.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.25);
    for (var i = 0; i < _pts.length - 1; i++) {
      canvas.drawLine(p(i), p(i + 1), line);
    }
    // Estrellas que brillan.
    for (var i = 0; i < _pts.length; i++) {
      final glow = 0.5 + 0.5 * sin(t * 2 * pi + i);
      canvas.drawCircle(
        p(i),
        6 + 4 * glow,
        Paint()
          ..color = const Color(0xFFF0A344).withValues(alpha: 0.5 + 0.4 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p(i), 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => true;
}

/// Escena 4: corazones juntos.
class _HeartsPainter extends CustomPainter {
  final double t;
  _HeartsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final specs = [
      [0.32, 0.55, 0.5, const Color(0xFFE5484D)],
      [0.62, 0.5, 0.44, const Color(0xFFE86A9B)],
      [0.5, 0.68, 0.4, const Color(0xFFF0A344)],
    ];
    for (var i = 0; i < specs.length; i++) {
      final s = specs[i];
      final float = 0.03 * sin(t * 2 * pi + i * 1.6);
      final hs = Size(size.width * (s[2] as double), size.height * (s[2] as double));
      canvas.save();
      canvas.translate(size.width * (s[0] as double) - hs.width / 2,
          size.height * ((s[1] as double) + float) - hs.height / 2);
      canvas.drawPath(
        _heartPath(hs),
        Paint()
          ..color = (s[3] as Color).withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => true;
}

/// Orbe de voz que late y muestra ondas alrededor.
class _VoiceOrb extends StatelessWidget {
  final double t;
  final bool playing;
  const _VoiceOrb({required this.t, required this.playing});

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + 0.06 * sin(t * 2 * pi * 2);
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _WavePainter(t, playing),
        child: Center(
          child: Transform.scale(
            scale: playing ? pulse : 1,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0A344), Color(0xFFC7562F)],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x66E08A2E), blurRadius: 44, spreadRadius: 4),
                ],
              ),
              child: Icon(
                  playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 56),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final bool playing;
  _WavePainter(this.t, this.playing);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width * 0.32;
    for (var ring = 0; ring < 3; ring++) {
      final phase = (t + ring / 3) % 1;
      final r = base + phase * base * 0.9;
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
