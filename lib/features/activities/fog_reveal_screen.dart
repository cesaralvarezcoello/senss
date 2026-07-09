import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/emotions.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/dictate_field.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// "La niebla que se despeja": la foto empieza borrosa y se aclara conforme la
/// persona recuerda datos (quién, qué emoción) o completa lo que falta (la
/// descripción). Recordar revela la imagen. Sin fallo; dificultad por edad.
class FogRevealScreen extends StatefulWidget {
  final MemoryWithAudios item;
  final List<MemoryWithAudios> feed;
  const FogRevealScreen({super.key, required this.item, required this.feed});

  @override
  State<FogRevealScreen> createState() => _FogRevealScreenState();
}

/// Una opción de respuesta.
class _Opt {
  final String label;
  final String sub;
  final String emoji;
  const _Opt(this.label, {this.sub = '', this.emoji = ''});
}

/// Una pregunta: de opción o abierta (para completar un dato).
class _Q {
  final String prompt;
  final bool open;
  final List<_Opt> options;
  final int correct;
  const _Q.choice(this.prompt, this.options, this.correct) : open = false;
  const _Q.open(this.prompt)
      : open = true,
        options = const [],
        correct = -1;
}

class _FogRevealScreenState extends State<FogRevealScreen> {
  static const _maxSigma = 26.0;
  final _picker = Picker();
  final _player = AudioPlayerService();
  final _text = TextEditingController();

  late final List<_Q> _qs;
  int _index = 0;
  bool _answered = false;
  int? _chosen;
  double _sigma = _maxSigma;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _qs = _buildQuestions();
    if (_qs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _text.dispose();
    super.dispose();
  }

  List<_Q> _buildQuestions() {
    final choices = context.read<ProfileStore>().profile.choiceCount;
    final m = widget.item;
    final qs = <_Q>[];

    // 1) ¿De quién es la voz?
    if (m.audios.isNotEmpty) {
      final correctAuthor = m.audios.first.authorName;
      final others = [
        for (final it in widget.feed)
          for (final a in it.audios) a.authorName
      ].where((a) => a != correctAuthor).toSet().toList();
      final picked = _picker.shuffle([
        correctAuthor,
        ..._picker.sample(others, choices - 1),
      ]);
      final opts = picked.map((a) {
        final (n, r) = splitAuthor(a);
        return _Opt(n, sub: r);
      }).toList();
      qs.add(_Q.choice('¿De quién es esta voz?', opts,
          picked.indexOf(correctAuthor)));
    }

    // 2) ¿Qué emoción guarda? (si alguna voz la tiene)
    final emo = m.audios
        .map((a) => a.emotionTag)
        .firstWhere((e) => e != null, orElse: () => null);
    if (emo != null) {
      final others =
          AppConstants.emotionTags.where((e) => e != emo).toList();
      final picked =
          _picker.shuffle([emo, ..._picker.sample(others, choices - 1)]);
      final opts = picked
          .map((e) => _Opt(e, emoji: EmotionStyle.of(e).emoji))
          .toList();
      qs.add(_Q.choice('¿Qué sentimiento guarda?', opts, picked.indexOf(emo)));
    }

    // 3) Completar la descripción si falta.
    if (m.memory.description == null || m.memory.description!.trim().isEmpty) {
      qs.add(const _Q.open('¿Qué recuerdas de este día?'));
    }

    // Límite según edad.
    final cap = context.read<ProfileStore>().profile.isSenior ? 2 : 3;
    return qs.take(cap).toList();
  }

  void _updateFog() {
    final answered = _index;
    _sigma = _qs.isEmpty ? 0 : _maxSigma * (1 - answered / _qs.length);
  }

  void _answer(int i) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _chosen = i;
    });
  }

  void _advance() {
    setState(() {
      _index++;
      _answered = false;
      _chosen = null;
      _updateFog();
    });
    if (_index >= _qs.length) _finish();
  }

  Future<void> _saveOpen() async {
    final t = _text.text.trim();
    if (t.isNotEmpty) {
      await context
          .read<MemoryProvider>()
          .updateMemory(widget.item.memory.copyWith(description: t));
    }
    _advance();
  }

  Future<void> _finish() async {
    setState(() {
      _sigma = 0;
      _done = true;
    });
    if (widget.item.audios.isNotEmpty) {
      _player.playSequence(
          widget.item.audios.map((a) => a.audioPath).toList());
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      await showCelebration(context,
          message: '¡Se aclaró el recuerdo!',
          sub: widget.item.memory.title,
          nextLabel: 'Seguir');
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = (!_done && _index < _qs.length) ? _qs[_index] : null;
    return ActivityShell(
      title: 'La niebla se despeja',
      child: ListView(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _sigma),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (ctx, sigma, child) => ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
                  child: child,
                ),
                child: RefImage(widget.item.memory.photoPath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          if (q == null)
            const AppText('¡Lo recordaste! 💛',
                variant: AppTextVariant.titleM, align: TextAlign.center)
          else if (q.open)
            _openQuestion(q)
          else
            _choiceQuestion(q),
        ],
      ),
    );
  }

  Widget _choiceQuestion(_Q q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(q.prompt, variant: AppTextVariant.titleM),
        const SizedBox(height: AppSpace.md),
        for (var i = 0; i < q.options.length; i++) ...[
          ChoiceButton(
            label: q.options[i].label,
            sublabel: q.options[i].sub,
            emoji: q.options[i].emoji.isEmpty ? null : q.options[i].emoji,
            state: !_answered
                ? ChoiceState.idle
                : (i == q.correct
                    ? ChoiceState.correct
                    : (i == _chosen ? ChoiceState.wrong : ChoiceState.idle)),
            onTap: _answered ? null : () => _answer(i),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        if (_answered)
          AppButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward_rounded,
            onPressed: _advance,
          ),
      ],
    );
  }

  Widget _openQuestion(_Q q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(q.prompt, variant: AppTextVariant.titleM),
        const SizedBox(height: AppSpace.md),
        DictateField(
          controller: _text,
          maxLines: 3,
          hint: 'Dilo en voz alta o escríbelo…',
        ),
        const SizedBox(height: AppSpace.lg),
        AppButton(
          label: 'Continuar',
          icon: Icons.arrow_forward_rounded,
          onPressed: _saveOpen,
        ),
      ],
    );
  }
}
