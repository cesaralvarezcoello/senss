import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **Dial de audiografías** — un control giratorio (tipo corona de reloj / dial
/// de radio) para navegar y escuchar las voces de un recuerdo, una a una.
///
/// Diseñado para personas con Alzheimer:
/// - **Memoria motora:** girar un dial es un gesto físico grabado por décadas.
/// - **Errorless:** girar solo desliza entre voces; no hay forma de fallar.
/// - **Multisensorial:** cada paso da un *clic háptico*, mueve las marcas bajo un
///   puntero fijo (arriba) y resalta la voz activa; un aro fino muestra el
///   progreso de la voz que suena.
/// - **Doble modo:** quien entiende el giro lo gira; quien no, toca ◀◀ / ▶▶.
/// - **Marca al centro:** el ícono de senss preside el control, con su insignia
///   de play/pausa.
///
/// Es **controlado**: recibe [index] (voz activa), [playing] y [progress] del
/// exterior, y notifica intención con [onSeek] (ir a una voz) y [onPlayPause].
/// Al girar, muestra una *vista previa* local y confirma la selección al soltar
/// (girar para elegir, soltar para escuchar) — fluido y sin cortar el audio.
class AudioDial extends StatefulWidget {
  final int count;
  final int index;
  final bool playing;

  /// Progreso 0..1 de la voz que suena (para el aro fino interior).
  final double progress;

  /// Color ambiente (extraído de la foto) y su variante oscura.
  final Color color;
  final Color color2;

  /// Escala por perfil (p. ej. `Profile.iconScale`: mayor en tercera edad).
  final double scale;

  final bool enabled;
  final ValueChanged<int> onSeek;
  final VoidCallback onPlayPause;

  const AudioDial({
    super.key,
    required this.count,
    required this.index,
    required this.playing,
    required this.progress,
    required this.color,
    required this.color2,
    required this.onSeek,
    required this.onPlayPause,
    this.scale = 1.0,
    this.enabled = true,
  });

  @override
  State<AudioDial> createState() => _AudioDialState();
}

class _AudioDialState extends State<AudioDial> {
  double _acc = 0;
  double _lastAngle = 0;
  int? _preview;

  /// Ángulo por "muesca": cada ~26° de giro avanza/retrocede una voz.
  static const double _detent = pi / 7;

  int get _display => (_preview ?? widget.index);

  bool get _spinnable => widget.enabled && widget.count >= 2;

  @override
  void didUpdateWidget(AudioDial old) {
    super.didUpdateWidget(old);
    // El padre ya reflejó nuestra selección: soltamos la vista previa.
    if (_preview != null && widget.index == _preview) _preview = null;
  }

  double _angleAt(Offset local, double size) =>
      atan2(local.dy - size / 2, local.dx - size / 2);

  void _panStart(DragStartDetails d, double size) {
    if (!_spinnable) return;
    _lastAngle = _angleAt(d.localPosition, size);
    _acc = 0;
    _preview = widget.index;
  }

  void _panUpdate(DragUpdateDetails d, double size) {
    if (!_spinnable) return;
    final a = _angleAt(d.localPosition, size);
    var delta = a - _lastAngle;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _acc += delta;
    _lastAngle = a;
    var changed = false;
    while (_acc >= _detent) {
      _acc -= _detent;
      changed = _step(1) || changed;
    }
    while (_acc <= -_detent) {
      _acc += _detent;
      changed = _step(-1) || changed;
    }
    if (changed) setState(() {});
  }

  /// Avanza la vista previa; devuelve true si cambió (para el clic háptico).
  bool _step(int dir) {
    final next = (_display + dir).clamp(0, widget.count - 1);
    if (next != _preview) {
      _preview = next;
      HapticFeedback.selectionClick();
      return true;
    }
    return false; // tope: se siente un "muro", sin clic.
  }

  void _panEnd(DragEndDetails d) {
    final target = _preview;
    if (target != null && target != widget.index) {
      widget.onSeek(target); // confirmar: suena la voz elegida.
    } else {
      setState(() => _preview = null);
    }
  }

  void _tapSide(int dir) {
    final next = (_display + dir).clamp(0, widget.count - 1);
    if (next == _display) return;
    HapticFeedback.selectionClick();
    widget.onSeek(next);
  }

  @override
  Widget build(BuildContext context) {
    final d = (160.0 * widget.scale).clamp(148.0, 208.0);
    final btn = (54.0 * widget.scale).clamp(50.0, 68.0);
    final gap = d * 0.06;
    final atStart = _display <= 0;
    final atEnd = _display >= widget.count - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SideButton(
          icon: Icons.fast_rewind_rounded,
          size: btn,
          color: widget.color,
          enabled: _spinnable && !atStart,
          onTap: () => _tapSide(-1),
        ),
        SizedBox(width: gap),
        _jogWheel(d),
        SizedBox(width: gap),
        _SideButton(
          icon: Icons.fast_forward_rounded,
          size: btn,
          color: widget.color,
          enabled: _spinnable && !atEnd,
          onTap: () => _tapSide(1),
        ),
      ],
    );
  }

  Widget _jogWheel(double d) {
    final orb = d * 0.46;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // La rueda (giro) ocupa todo el cuadrado, debajo del orbe.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (e) => _panStart(e, d),
              onPanUpdate: (e) => _panUpdate(e, d),
              onPanEnd: _panEnd,
              child: CustomPaint(
                painter: _DialPainter(
                  count: widget.count,
                  index: _display.toDouble(),
                  progress: widget.playing ? widget.progress : 0,
                  color: widget.color,
                  playing: widget.playing,
                  enabled: widget.enabled,
                ),
              ),
            ),
          ),
          // El orbe de play/pausa va encima: su toque no llega a la rueda.
          GestureDetector(
            onTap:
                widget.enabled && widget.count > 0 ? widget.onPlayPause : null,
            child: _Orb(
              diameter: orb,
              color: widget.color,
              color2: widget.color2,
              playing: widget.playing,
              enabled: widget.enabled && widget.count > 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón lateral (◀◀ / ▶▶) para saltar de voz sin girar (accesibilidad).
class _SideButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _SideButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.05),
            border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.30 : 0.12)),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.3),
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Botón central de play/pausa: un orbe premium con degradado de marca, brillo
/// especular (cristal) y un glifo grande y centrado. El halo se intensifica al
/// sonar. El glifo de play se centra ópticamente (el triángulo se corre un poco
/// a la derecha para no verse desplazado).
class _Orb extends StatelessWidget {
  final double diameter;
  final Color color;
  final Color color2;
  final bool playing;
  final bool enabled;
  const _Orb({
    required this.diameter,
    required this.color,
    required this.color2,
    required this.playing,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = diameter * 0.46;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? [color, color2]
              : [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.08),
                ],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.65 : 0.25),
            width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
                alpha: enabled ? (playing ? 0.55 : 0.38) : 0.0),
            blurRadius: playing ? 32 : 22,
            spreadRadius: playing ? 1 : 0,
          ),
          const BoxShadow(
              color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Brillo especular arriba-izquierda (aspecto de cristal).
          Align(
            alignment: const Alignment(-0.35, -0.55),
            child: Container(
              width: diameter * 0.62,
              height: diameter * 0.42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(diameter),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: enabled ? 0.32 : 0.14),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Glifo play/pausa, con centrado óptico del triángulo.
          Transform.translate(
            offset: Offset(playing ? 0 : diameter * 0.035, 0),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.5),
              size: glyph,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta el aro: base, marcas por voz (que rotan bajo un puntero fijo arriba),
/// el aro fino de progreso de la voz activa, y el puntero.
class _DialPainter extends CustomPainter {
  final int count;
  final double index;
  final double progress;
  final Color color;
  final bool playing;
  final bool enabled;
  _DialPainter({
    required this.count,
    required this.index,
    required this.progress,
    required this.color,
    required this.playing,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = size.center(Offset.zero);
    final ringR = w / 2 - w * 0.06;
    final active = color.withValues(alpha: enabled ? 1 : 0.4);

    // Aro base.
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..color = Colors.white.withValues(alpha: enabled ? 0.10 : 0.05),
    );

    if (count >= 2 && count <= 30) {
      // Marcas: una por voz, giradas para dejar la activa arriba (-pi/2).
      final step = 2 * pi / count;
      for (var i = 0; i < count; i++) {
        final ang = -pi / 2 + (i - index) * step;
        final near = (i - index).abs();
        final isActive = near < 0.5;
        final dir = Offset(cos(ang), sin(ang));
        final r1 = ringR - w * 0.05;
        final r2 = ringR + (isActive ? w * 0.015 : 0);
        canvas.drawLine(
          c + dir * r1,
          c + dir * r2,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = isActive ? w * 0.03 : w * 0.016
            ..color = isActive
                ? active
                : Colors.white
                    .withValues(alpha: (0.30 / (1 + near)).clamp(0.05, 0.3)),
        );
      }
    } else if (count > 30) {
      // Muchas voces: un arco de posición proporcional (índice/total).
      final frac = (index / (count - 1)).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR),
        -pi / 2,
        2 * pi * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.03
          ..color = active.withValues(alpha: 0.6),
      );
    }

    // Aro fino de progreso de la voz activa (solo al sonar).
    if (playing && progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ringR - w * 0.075),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.02
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // Puntero fijo arriba: señala la voz activa.
    final tip = c + Offset(0, -ringR - w * 0.015);
    final pointer = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - w * 0.03, tip.dy - w * 0.05)
      ..lineTo(tip.dx + w * 0.03, tip.dy - w * 0.05)
      ..close();
    canvas.drawPath(pointer, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.index != index ||
      o.progress != progress ||
      o.playing != playing ||
      o.count != count ||
      o.color != color ||
      o.enabled != enabled;
}
