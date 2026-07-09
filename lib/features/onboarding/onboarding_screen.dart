import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';

/// Bienvenida sentimental: fondo cálido animado y, en el corazón, una página
/// donde se **siente** el poder de una voz querida (onda que late + sonido).
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
      final playing = s.playing && s.processingState != ProcessingState.completed;
      if (mounted && playing != _playing) setState(() => _playing = playing);
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
      _pages.nextPage(
          duration: AppMotion.base, curve: AppMotion.curve);
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
          // Fondo cálido con orbes que respiran.
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) =>
                CustomPaint(painter: _OrbPainter(_anim.value)),
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
                      _Page(
                        emoji: '🕯️',
                        title: 'Bienvenido a senss',
                        body: 'Un lugar seguro para guardar y revivir los '
                            'recuerdos más queridos.',
                      ),
                      _voicePage(),
                      _Page(
                        emoji: '🌳',
                        title: 'Toda una vida, en un lugar',
                        body: 'Fotos y voces que se acumulan con los años: un '
                            'tesoro para acompañar hoy… y para heredar mañana.',
                      ),
                      _Page(
                        emoji: '💛',
                        title: 'Juntos, sin prisa',
                        body: 'Jugar, recordar y sentir. Aquí nunca se falla y '
                            'nada se pierde.',
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

  // La página del corazón: el poder de la voz, para sentirlo.
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
          const AppText('Una voz tiene poder',
              variant: AppTextVariant.display,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
          const SizedBox(height: AppSpace.md),
          const AppText(
            'La voz de quien amas puede despertar un recuerdo dormido. '
            'Tócala y siéntelo.',
            variant: AppTextVariant.body,
            tone: AppTone.onPhoto,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Sintetiza una melodía cálida (WAV PCM16 mono) para "la voz".
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

class _Page extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _Page({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 92)),
          const SizedBox(height: AppSpace.xl),
          AppText(title,
              variant: AppTextVariant.display,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
          const SizedBox(height: AppSpace.md),
          AppText(body,
              variant: AppTextVariant.body,
              tone: AppTone.onPhoto,
              align: TextAlign.center),
        ],
      ),
    );
  }
}

/// Orbe de voz que late y muestra una onda alrededor.
class _VoiceOrb extends StatelessWidget {
  final double t;
  final bool playing;
  const _VoiceOrb({required this.t, required this.playing});

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + 0.06 * sin(t * 2 * pi * 2);
    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _WavePainter(t, playing),
        child: Center(
          child: Transform.scale(
            scale: playing ? pulse : 1,
            child: Container(
              width: 118,
              height: 118,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0A344), Color(0xFFC7562F)],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x66E08A2E), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Icon(playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 54),
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
    final base = size.width * 0.34;
    for (var ring = 0; ring < 3; ring++) {
      final phase = (t + ring / 3) % 1;
      final r = base + phase * base * 0.9;
      final opacity = (1 - phase) * (playing ? 0.5 : 0.22);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFF0A344).withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
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
      final cx = size.width * (o.dx + 0.05 * sin(t * 2 * pi * o.speed + o.phase * 6));
      final cy = size.height *
          (o.dy + 0.05 * cos(t * 2 * pi * o.speed + o.phase * 6));
      final radius = size.width * o.radius;
      final center = Offset(cx, cy);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [
          o.color.withValues(alpha: 0.35),
          o.color.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
