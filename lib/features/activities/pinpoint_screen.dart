import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// **Adivina quién** — inspirado en los juegos diarios de pistas (tipo Pinpoint),
/// pero con tus recuerdos. senss da pistas de una persona, una a una (parentesco,
/// emoción de su voz, en qué recuerdos aparece…) y hay que adivinar quién es.
/// Al acertar, suena su voz. Sin fallo: cada intento revela una pista más.
class PinpointScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const PinpointScreen({super.key, required this.feed});

  @override
  State<PinpointScreen> createState() => _PinpointScreenState();
}

class _PinpointScreenState extends State<PinpointScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  late final List<Voice> _voices;
  late final List<String> _authors;
  late final int _choices;

  late String _target;
  late List<String> _options;
  late List<String> _clues;
  int _revealed = 1;
  bool _answered = false;
  final Set<String> _wrong = {};

  @override
  void initState() {
    super.initState();
    _voices = voicesOf(widget.feed);
    _authors = _voices.map((v) => v.audio.authorName).toSet().toList();
    _choices = context.read<ProfileStore>().profile.choiceCount;
    _newRound();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _newRound() {
    _target = _picker.pick(_authors);
    final others = _authors.where((a) => a != _target).toList();
    _options =
        _picker.shuffle([_target, ..._picker.sample(others, _choices - 1)]);
    _clues = _buildClues(_target);
    _revealed = 1;
    _answered = false;
    _wrong.clear();
    setState(() {});
  }

  /// Construye las pistas de menos a más reveladoras.
  List<String> _buildClues(String author) {
    final (_, rel) = splitAuthor(author);
    final tv = _voices.where((v) => v.audio.authorName == author).toList();
    final clues = <String>[];
    final relWord = rel
        .replaceFirst(RegExp(r'^(tu|mi|su)\s+', caseSensitive: false), '')
        .trim();
    if (relWord.isNotEmpty) clues.add('Es su $relWord.');
    for (final v in tv) {
      final e = v.audio.emotionTag;
      if (e != null && e.trim().isNotEmpty) {
        clues.add('Su voz guarda $e.');
        break;
      }
    }
    final mems = tv.map((v) => v.memory.id).toSet().length;
    if (mems >= 1) {
      clues.add(mems == 1
          ? 'Está en un recuerdo suyo.'
          : 'Está en $mems recuerdos suyos.');
    }
    for (final v in tv) {
      final t = v.memory.title.trim();
      if (t.isNotEmpty) {
        clues.add('Aparece en "$t".');
        break;
      }
    }
    if (clues.isEmpty) clues.add('Alguien que le quiere mucho.');
    return clues;
  }

  void _revealMore() {
    if (_revealed < _clues.length) setState(() => _revealed++);
  }

  void _answer(String author) {
    if (_answered) return;
    if (author == _target) {
      setState(() => _answered = true);
      final tv = _voices.where((v) => v.audio.authorName == _target).toList();
      if (tv.isNotEmpty) _player.playFile(_picker.pick(tv).audio.audioPath);
    } else {
      setState(() {
        _wrong.add(author);
        if (_revealed < _clues.length) _revealed++; // ayuda con otra pista
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (cName, cRel) = splitAuthor(_target);
    return ActivityShell(
      title: 'Adivina quién',
      child: ListView(
        children: [
          const AppText('Descúbrelo con las pistas',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.lg),
          for (var i = 0; i < _revealed && i < _clues.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: c.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        AppText(_clues[i], variant: AppTextVariant.bodyStrong),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (!_answered && _revealed < _clues.length) ...[
            const SizedBox(height: AppSpace.xs),
            AppButton(
              label: 'Otra pista',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.tonal,
              onPressed: _revealMore,
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          const AppText('¿Quién es?', variant: AppTextVariant.titleM),
          const SizedBox(height: AppSpace.md),
          for (final o in _options) ...[
            Builder(builder: (_) {
              final (n, r) = splitAuthor(o);
              final state = _answered && o == _target
                  ? ChoiceState.correct
                  : (_wrong.contains(o) ? ChoiceState.wrong : ChoiceState.idle);
              final disabled = _answered || _wrong.contains(o);
              return ChoiceButton(
                label: n,
                sublabel: r,
                state: state,
                onTap: disabled ? null : () => _answer(o),
              );
            }),
            const SizedBox(height: AppSpace.md),
          ],
          if (_answered) ...[
            const SizedBox(height: AppSpace.sm),
            AppText('¡Es $cName${cRel.isEmpty ? '' : ', $cRel'}! 💛',
                variant: AppTextVariant.bodyStrong, align: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: 'Otra ronda',
              icon: Icons.arrow_forward_rounded,
              onPressed: _newRound,
            ),
          ],
        ],
      ),
    );
  }
}
