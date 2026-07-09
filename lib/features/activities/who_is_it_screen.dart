import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// Reto: suena una voz; ¿de quién es? Refuerza el reconocimiento de las
/// personas queridas (lo primero que se pierde). Sin fallo: si no acierta,
/// se revela con cariño y suena de nuevo.
class WhoIsItScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const WhoIsItScreen({super.key, required this.feed});

  @override
  State<WhoIsItScreen> createState() => _WhoIsItScreenState();
}

class _WhoIsItScreenState extends State<WhoIsItScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  late final List<Voice> _voices;
  late final List<String> _authors;
  late final int _choices;

  late Voice _target;
  late List<String> _options;
  bool _answered = false;
  String? _chosen;

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
    _target = _picker.pick(_voices);
    final others =
        _authors.where((a) => a != _target.audio.authorName).toList();
    _options = _picker.shuffle([
      _target.audio.authorName,
      ..._picker.sample(others, _choices - 1),
    ]);
    _answered = false;
    _chosen = null;
    setState(() {});
    _play();
  }

  void _play() => _player.playFile(_target.audio.audioPath);

  void _answer(String author) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _chosen = author;
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final correct = _target.audio.authorName;
    final (cName, cRel) = splitAuthor(correct);

    return ActivityShell(
      title: '¿De quién es esta voz?',
      child: ListView(
        children: [
          const AppText('Escucha y elige quién habla',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: 'Escuchar de nuevo',
            icon: Icons.volume_up_rounded,
            variant: AppButtonVariant.tonal,
            onPressed: _play,
          ),
          const SizedBox(height: AppSpace.xl),
          for (final o in _options) ...[
            Builder(builder: (_) {
              final (n, r) = splitAuthor(o);
              final state = !_answered
                  ? ChoiceState.idle
                  : (o == correct
                      ? ChoiceState.correct
                      : (o == _chosen ? ChoiceState.wrong : ChoiceState.idle));
              return ChoiceButton(
                label: n,
                sublabel: r,
                state: state,
                onTap: _answered ? null : () => _answer(o),
              );
            }),
            const SizedBox(height: AppSpace.md),
          ],
          if (_answered) ...[
            const SizedBox(height: AppSpace.sm),
            AppText(
              _chosen == correct
                  ? '¡Muy bien! Es $cName${cRel.isEmpty ? '' : ', $cRel'}.'
                  : 'Es $cName${cRel.isEmpty ? '' : ', $cRel'}.',
              variant: AppTextVariant.bodyStrong,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: 'Otra voz',
              icon: Icons.arrow_forward_rounded,
              onPressed: _newRound,
            ),
          ],
        ],
      ),
    );
  }
}
