import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/profile.dart';
import '../../data/models/audiography.dart';
import '../../data/models/memory_with_audios.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/tts_service.dart';
import '../../state/memory_provider.dart';
import '../../design/components/app_text.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';

/// **Modo conversación** — para personas con Alzheimer: en vez de "usar una app",
/// la persona *habla con senss*. senss saluda, muestra un recuerdo, reproduce la
/// voz del ser querido, hace una pregunta cariñosa y **escucha** la respuesta
/// hablada. Sin errores posibles: cualquier respuesta se recibe con calidez.
///
/// Todo on-device: voz de senss (TTS del sistema) + reconocimiento (STT). Doble
/// modo: se puede hablar o tocar los botones grandes.
class ConverseScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  final int startIndex;

  /// Si saluda al entrar. Al lanzarse por "detenerse en un recuerdo" (dwell) se
  /// omite el saludo y va directo a hablar de esa foto.
  final bool greet;

  const ConverseScreen({
    super.key,
    required this.feed,
    this.startIndex = 0,
    this.greet = true,
  });

  @override
  State<ConverseScreen> createState() => _ConverseScreenState();
}

enum _Phase { speaking, listening, idle }

class _ConverseScreenState extends State<ConverseScreen>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  final SpeechToText _stt = SpeechToText();
  final AudioPlayerService _player = AudioPlayerService();
  late final AnimationController _anim;
  late final MemoryProvider _memories;

  bool _sttReady = false;
  int _index = 0;
  int _qi = 0;
  _Phase _phase = _Phase.idle;
  String _caption = '';

  Profile _profile = const Profile();
  bool _multiVoice = false;
  final Set<String> _justCompleted = {}; // recuerdos ya preguntados esta sesión

  static const _questions = [
    '¿La recuerda?',
    '¿Qué siente al verla?',
    '¿Quién cree que la acompaña aquí?',
    '¿Le gustó escuchar esa voz?',
  ];
  static const _affirms = [
    'Qué bonito.',
    'Me alegra escucharle.',
    'Gracias por contarme.',
    'Qué recuerdo tan lindo.',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _profile = context.read<ProfileStore>().profile;
    _memories = context.read<MemoryProvider>();
    // ¿Hay voces de 2+ personas distintas? Entonces invitamos a pedir por nombre.
    final authors = <String>{};
    for (final m in widget.feed) {
      for (final a in m.audios) {
        authors.add(_norm(_split(a.authorName).$1));
      }
    }
    _multiVoice = authors.length >= 2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _anim.dispose();
    _tts.dispose();
    _player.dispose();
    try {
      _stt.cancel();
    } catch (_) {}
    super.dispose();
  }

  MemoryWithAudios get _m => widget.feed[_index.clamp(0, widget.feed.length - 1)];

  // ---------- Conversación ----------

  Future<void> _start() async {
    if (widget.greet) {
      final name = _profile.name.trim();
      await _say(name.isEmpty
          ? 'Hola. Soy senss. Estoy aquí con usted, sin prisa.'
          : 'Hola, $name. Soy senss. Estoy aquí con usted, sin prisa.');
    }
    await _present();
  }

  /// Presenta el recuerdo hablando: identifica de quién es y **pregunta** antes
  /// de reproducir. Al decir "sí" (o ante cualquier respuesta cálida), suena.
  Future<void> _present() async {
    if (!mounted) return;
    setState(() {}); // refresca la foto de fondo
    final m = _m;

    if (m.audios.isEmpty) {
      if (m.memory.title.trim().isNotEmpty) {
        await _say('Este recuerdo se llama: ${m.memory.title.trim()}.');
      }
      if (await _maybeComplete(m)) return;
      await _say('¿Qué ve en esta foto? Cuénteme.');
      await _autoListen();
      return;
    }

    // Identifica a la persona de la voz: "Esta foto es de su nieto Juan."
    final (n, r) = _split(m.audios.first.authorName);
    final rel = _possessive(r);
    if (rel.isNotEmpty && n.isNotEmpty) {
      await _say('Esta foto es de $rel $n.');
    } else if (n.isNotEmpty) {
      await _say('Esta foto es de $n.');
    } else if (m.memory.title.trim().isNotEmpty) {
      await _say('Este recuerdo se llama: ${m.memory.title.trim()}.');
    }

    // Pregunta antes de reproducir.
    await _say(m.audios.length > 1
        ? '¿Quiere escuchar sus recuerdos?'
        : '¿Quiere escuchar su voz?');
    final text = await _listen();

    // Ruteo cálido y errorless: "no" salta; un nombre pone esa voz; cualquier
    // otra cosa (sí, silencio, algo ambiguo) reproduce — vino a escuchar.
    if (_intentOf(text) == _Intent.no) {
      await _say('Está bien, sin prisa.');
      await _offerNext();
      return;
    }
    if (text != null) {
      final v = _findVoice(text);
      if (v != null) {
        await _playNamedVoice(v.$1, v.$2);
        return;
      }
    }
    if (_intentOf(text) == _Intent.next) {
      await _nextMemory();
      return;
    }
    await _say('Con mucho cariño.');
    await _playAll(m);
    if (await _maybeComplete(m)) return;
    await _say(_questions[_qi++ % _questions.length]);
    await _autoListen();
  }

  Future<void> _autoListen() async {
    final text = await _listen();
    if (!mounted) return;
    await _handle(text);
  }

  /// Escucha una vez, mostrando el estado en el orbe y el subtítulo.
  Future<String?> _listen() async {
    if (!mounted) return null;
    setState(() {
      _phase = _Phase.listening;
      _caption = 'Le escucho…';
    });
    final text = await _listenOnce();
    if (mounted) setState(() => _phase = _Phase.idle);
    return text;
  }

  Future<void> _handle(String? text) async {
    final intent = _intentOf(text);
    // "No quiero / basta" se respeta antes que nada.
    if (intent == _Intent.no) {
      await _say('Está bien. Descanse. Aquí estaré cuando quiera.');
      _end();
      return;
    }
    // Si nombró a una persona (o su parentesco), pon su voz — tiene prioridad.
    if (text != null) {
      final v = _findVoice(text);
      if (v != null) {
        await _playNamedVoice(v.$1, v.$2);
        return;
      }
    }
    switch (intent) {
      case _Intent.no:
        return; // ya tratado arriba
      case _Intent.next:
        await _say('Vamos con otro.');
        await _nextMemory();
        return;
      case _Intent.again:
        if (_m.audios.isNotEmpty) {
          await _say('Claro, escúchela otra vez.');
          await _playAll(_m);
          await _offerNext();
        } else {
          await _nextMemory();
        }
        return;
      case _Intent.who:
        if (_m.audios.isNotEmpty) {
          final (n, r) = _split(_m.audios.first.authorName);
          final rel = _possessive(r);
          await _say(rel.isEmpty
              ? 'Es $n. Le quiere mucho.'
              : 'Es $rel $n. Le quiere mucho.');
        } else {
          await _say('Es una persona que le quiere.');
        }
        await _offerNext();
        return;
      case _Intent.yes:
        await _say(_affirms[_qi++ % _affirms.length]);
        await _offerNext();
        return;
      case _Intent.unknown:
        if (text == null) {
          await _say('Cuando quiera, toque "Hablar" y me cuenta.');
          _idle();
        } else {
          await _say('Qué bonito lo que dice. Gracias por compartirlo.');
          await _offerNext();
        }
        return;
    }
  }

  Future<void> _offerNext() async {
    await _say(_multiVoice
        ? '¿Vemos otro recuerdo, o quiere escuchar a alguien? Dígame un nombre.'
        : '¿Vemos otro recuerdo? Diga "otra", o toque la flecha.');
    await _autoListen();
  }

  Future<void> _nextMemory() async {
    if (widget.feed.length <= 1) {
      await _say('Es el único recuerdo por ahora. Lo vemos otra vez.');
    } else {
      _index = (_index + 1) % widget.feed.length;
    }
    await _present();
  }

  void _idle() {
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  void _end() {
    _tts.stop();
    _player.stop();
    if (mounted) Navigator.of(context).maybePop();
  }

  // ---------- Voz de senss / escucha ----------

  Future<void> _say(String text) async {
    if (!mounted) return;
    setState(() {
      _caption = text;
      _phase = _Phase.speaking;
    });
    final sw = Stopwatch()..start();
    await _tts.speak(text);
    // Piso de tiempo para que el subtítulo se pueda leer (y en web, donde el
    // TTS puede no bloquear, la conversación mantiene su ritmo).
    final floor = (text.length * 42).clamp(900, 4500);
    final left = floor - sw.elapsedMilliseconds;
    if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
    if (mounted && _phase == _Phase.speaking) {
      setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _playVoice(Audiography a) async {
    if (!mounted) return;
    setState(() => _phase = _Phase.speaking);
    try {
      await _player.playFile(a.audioPath);
    } catch (_) {}
    final ms = a.durationMs.clamp(1000, 15000) + 500;
    await Future<void>.delayed(Duration(milliseconds: ms));
    if (mounted && _phase == _Phase.speaking) {
      setState(() => _phase = _Phase.idle);
    }
  }

  /// Reproduce en secuencia todas las voces del recuerdo (sus "recuerdos").
  Future<void> _playAll(MemoryWithAudios m) async {
    if (m.audios.isEmpty || !mounted) return;
    setState(() => _phase = _Phase.speaking);
    try {
      await _player.playSequence(m.audios.map((a) => a.audioPath).toList());
    } catch (_) {}
    var total = 0;
    for (final a in m.audios) {
      total += a.durationMs.clamp(1000, 15000) + 400;
    }
    await Future<void>.delayed(Duration(milliseconds: total.clamp(1200, 90000)));
    if (mounted && _phase == _Phase.speaking) {
      setState(() => _phase = _Phase.idle);
    }
  }

  /// Convierte el parentesco a tercera persona: "tu nieto" → "su nieto".
  static String _possessive(String rel) {
    var r = rel.trim();
    if (r.isEmpty) return '';
    r = r.replaceFirst(
        RegExp(r'^(tu|mi|su)\s+', caseSensitive: false), 'su ');
    if (!RegExp(r'^su\s', caseSensitive: false).hasMatch(r)) r = 'su $r';
    return r;
  }

  // ---------- Completar datos hablando ----------

  /// Si al recuerdo le falta nombre o descripción, senss lo pregunta y **guarda**
  /// lo que la persona dice (enriquece el archivo, hablando). Pregunta una cosa
  /// por visita; devuelve true si preguntó (y ya encadenó el siguiente turno).
  Future<bool> _maybeComplete(MemoryWithAudios m) async {
    if (_justCompleted.contains(m.memory.id)) return false;
    final needTitle = m.memory.title.trim().isEmpty;
    final needDesc = (m.memory.description ?? '').trim().isEmpty;
    if (!needTitle && !needDesc) return false;
    _justCompleted.add(m.memory.id); // una sola vez por sesión, sin insistir
    if (needTitle) {
      await _say('Este recuerdo aún no tiene nombre. ¿Cómo lo llamamos?');
      final t = await _listen();
      final i = _intentOf(t);
      if (t != null && i != _Intent.no && i != _Intent.next) {
        final title = _clean(t, 60);
        await _saveMemory(m, title: title);
        await _say('Gracias. Lo guardé: $title.');
      } else {
        await _say('Está bien, lo dejamos así.');
      }
      await _offerNext();
      return true;
    }
    // Falta la descripción: pídela y guarda lo que cuente.
    await _say('¿Qué recuerda de este día? Cuénteme.');
    final t = await _listen();
    final i = _intentOf(t);
    if (t != null && t.trim().length >= 3 && i != _Intent.no && i != _Intent.next) {
      await _saveMemory(m, description: _clean(t, 280));
      await _say('Qué bonito. Lo guardé con su recuerdo.');
    } else {
      await _say('Gracias.');
    }
    await _offerNext();
    return true;
  }

  Future<void> _saveMemory(MemoryWithAudios cur,
      {String? title, String? description}) async {
    final updated = cur.memory.copyWith(title: title, description: description);
    // Actualiza el snapshot local para no volver a preguntar en esta sesión.
    final i = _index.clamp(0, widget.feed.length - 1);
    widget.feed[i] = MemoryWithAudios(updated, cur.audios);
    try {
      await _memories.updateMemory(updated);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  static String _clean(String s, int max) {
    var t = s.trim();
    if (t.isEmpty) return t;
    t = t[0].toUpperCase() + t.substring(1);
    if (t.length > max) t = t.substring(0, max).trim();
    return t;
  }

  Future<String?> _listenOnce() async {
    try {
      if (!_sttReady) {
        _sttReady = await _stt.initialize(onStatus: (_) {}, onError: (_) {});
      }
    } catch (_) {
      _sttReady = false;
    }
    if (!_sttReady) return null;
    final c = Completer<String?>();
    var last = '';
    try {
      await _stt.listen(
        localeId: 'es_ES',
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        onResult: (r) {
          last = r.recognizedWords;
          if (r.finalResult && !c.isCompleted) c.complete(last);
        },
      );
    } catch (_) {
      return null;
    }
    final res = await c.future
        .timeout(const Duration(seconds: 11), onTimeout: () => last);
    try {
      await _stt.stop();
    } catch (_) {}
    final out = (res ?? '').trim();
    return out.isEmpty ? null : out;
  }

  // ---------- Utilidades ----------

  static (String, String) _split(String author) {
    final parts = author.split(',');
    final name = parts.first.trim();
    final rel = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    return (name.isEmpty ? author.trim() : name, rel);
  }

  static String _norm(String s) {
    s = s.toLowerCase();
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }

  /// Palabras (tokens a-z) de un texto, ya normalizadas.
  static List<String> _words(String s) => _norm(s)
      .split(RegExp(r'[^a-z]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Palabras vacías del parentesco ("tu hija" -> {hija}).
  static const _relStop = {
    'tu', 'mi', 'su', 'el', 'la', 'los', 'las', 'de', 'mis', 'tus', 'un', 'una'
  };

  /// Busca en TODO el feed una voz cuyo autor (nombre o parentesco) haya sido
  /// nombrado en [text]. Prefiere el recuerdo actual en caso de empate.
  /// Devuelve (índice de recuerdo, índice de audio) o null.
  (int, int)? _findVoice(String text) {
    final said = _words(text).toSet();
    if (said.isEmpty) return null;
    // Recorre primero el recuerdo actual, luego el resto (empates -> actual).
    final order = <int>[
      _index.clamp(0, widget.feed.length - 1),
      for (var i = 0; i < widget.feed.length; i++)
        if (i != _index) i,
    ];
    var bestScore = 0;
    (int, int)? best;
    for (final mi in order) {
      final audios = widget.feed[mi].audios;
      for (var ai = 0; ai < audios.length; ai++) {
        final (n, r) = _split(audios[ai].authorName);
        var score = 0;
        for (final w in _words(n)) {
          if (w.length >= 3 && said.contains(w)) score += 2;
        }
        for (final w in _words(r)) {
          if (w.length >= 3 && !_relStop.contains(w) && said.contains(w)) {
            score += 1;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = (mi, ai);
        }
      }
    }
    return best;
  }

  Future<void> _playNamedVoice(int mem, int audio) async {
    final m = widget.feed[mem];
    if (audio < 0 || audio >= m.audios.length) return;
    final a = m.audios[audio];
    final (n, r) = _split(a.authorName);
    final rel = _possessive(r);
    if (mem != _index) {
      _index = mem;
      if (mounted) setState(() {}); // cambia la foto de fondo al recuerdo suyo
    }
    await _say(rel.isEmpty
        ? 'Claro, aquí está la voz de $n.'
        : 'Claro, aquí está $rel $n.');
    await _playVoice(a);
    await _say(rel.isEmpty ? 'Esa fue $n.' : 'Esa fue $rel $n.');
    await _offerNext();
  }

  _Intent _intentOf(String? text) {
    if (text == null) return _Intent.unknown;
    final t = _norm(text);
    bool has(List<String> ks) => ks.any(t.contains);
    if (has([
      'no quiero',
      'ya no',
      'basta',
      'parar',
      'para ya',
      'salir',
      'descansar',
      'terminar',
      'adios',
      'despues',
    ])) {
      return _Intent.no;
    }
    if (has(['otra', 'otro', 'siguiente', 'cambia', 'nueva', 'ver mas', 'distinta'])) {
      return _Intent.next;
    }
    if (has(['de nuevo', 'otra vez', 'repite', 'repetir', 'escuchar', 'escucha', 'oir', 'suena'])) {
      return _Intent.again;
    }
    if (has(['quien', 'de quien'])) return _Intent.who;
    if (has(['si', 'claro', 'bueno', 'dale', 'me gusta', 'quiero', 'sigue', 'vale', 'por supuesto'])) {
      return _Intent.yes;
    }
    return _Intent.unknown;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final busy = _phase == _Phase.speaking;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter:
                ImageFilter.blur(sigmaX: 45, sigmaY: 45, tileMode: TileMode.clamp),
            child: Transform.scale(
              scale: 1.2,
              child: RefImage(m.memory.photoPath, fit: BoxFit.cover),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC1A120C), Color(0xF2000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: _end,
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      label: const AppText('Descansar',
                          variant: AppTextVariant.label, tone: AppTone.onPhoto),
                    ),
                  ),
                  const Spacer(),
                  // Retrato del recuerdo, redondo y cálido.
                  Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x99000000), blurRadius: 30),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RefImage(m.memory.photoPath, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  // Orbe de senss (habla / escucha).
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) =>
                        _TalkOrb(t: _anim.value, phase: _phase),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  // Subtítulo de lo que dice senss (grande, legible).
                  SizedBox(
                    height: 96,
                    child: Center(
                      child: AppText(
                        _caption,
                        variant: AppTextVariant.titleL,
                        tone: AppTone.onPhoto,
                        align: TextAlign.center,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Botones grandes (doble modo: hablar o tocar).
                  Row(
                    children: [
                      Expanded(
                        child: _BigAction(
                          icon: Icons.mic_rounded,
                          label: 'Hablar',
                          highlight: true,
                          enabled: !busy,
                          onTap: _autoListen,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _BigAction(
                          icon: Icons.replay_rounded,
                          label: 'De nuevo',
                          enabled: !busy && m.audios.isNotEmpty,
                          onTap: () => _playVoice(m.audios.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  _BigAction(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Ver otro recuerdo',
                    enabled: !busy,
                    onTap: _nextMemory,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Intent { yes, no, next, again, who, unknown }

/// Orbe de senss: ondas al hablar, anillo pulsante al escuchar.
class _TalkOrb extends StatelessWidget {
  final double t;
  final _Phase phase;
  const _TalkOrb({required this.t, required this.phase});

  @override
  Widget build(BuildContext context) {
    final listening = phase == _Phase.listening;
    final speaking = phase == _Phase.speaking;
    final pulse = 1 + 0.06 * sin(t * 2 * pi);
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _OrbWaves(t: t, active: listening || speaking, listening: listening),
        child: Center(
          child: Transform.scale(
            scale: speaking ? pulse : 1,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0A344), Color(0xFFC7562F)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE08A2E)
                        .withValues(alpha: (listening || speaking) ? 0.6 : 0.3),
                    blurRadius: 34,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                listening
                    ? Icons.mic_rounded
                    : (speaking ? Icons.graphic_eq_rounded : Icons.favorite_rounded),
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbWaves extends CustomPainter {
  final double t;
  final bool active;
  final bool listening;
  _OrbWaves({required this.t, required this.active, required this.listening});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = size.center(Offset.zero);
    final base = size.width * 0.32;
    final color = listening ? const Color(0xFF6AC48A) : const Color(0xFFF0A344);
    for (var ring = 0; ring < 3; ring++) {
      final phase = (t + ring / 3) % 1;
      final r = base + phase * base * 0.9;
      final opacity = (1 - phase) * 0.5;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbWaves old) => true;
}

/// Botón grande y claro (con estado activo/atenuado).
class _BigAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool highlight;
  final VoidCallback onTap;
  const _BigAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: highlight
                    ? const Color(0xFFE08A2E).withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Flexible(
                    child: AppText(label,
                        variant: AppTextVariant.bodyStrong,
                        tone: AppTone.onPhoto,
                        maxLines: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
