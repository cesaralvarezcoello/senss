import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/emotions.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// Reto: escucha una voz y elige la emoción que guarda. Conecta el afecto; no
/// hay respuesta "mala".
class EmotionGuessScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const EmotionGuessScreen({super.key, required this.feed});

  @override
  State<EmotionGuessScreen> createState() => _EmotionGuessScreenState();
}

class _EmotionGuessScreenState extends State<EmotionGuessScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  late final List<Voice> _voices;

  late Voice _target;
  late List<String> _options;
  late final int _choices;
  bool _answered = false;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _voices =
        voicesOf(widget.feed).where((v) => v.audio.emotionTag != null).toList();
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
    final correct = _target.audio.emotionTag!;
    final others =
        AppConstants.emotionTags.where((e) => e != correct).toList();
    _options = _picker.shuffle([correct, ..._picker.sample(others, _choices - 1)]);
    _answered = false;
    _chosen = null;
    setState(() {});
    _play();
  }

  void _play() => _player.playFile(_target.audio.audioPath);

  void _answer(String e) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _chosen = e;
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final correct = _target.audio.emotionTag!;
    final (name, _) = splitAuthor(_target.audio.authorName);

    return ActivityShell(
      title: 'Adivina la emoción',
      child: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: memoryThumb(_target.memory.photoPath, radius: AppRadius.lg),
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: 'Escuchar a $name',
            icon: Icons.volume_up_rounded,
            variant: AppButtonVariant.tonal,
            onPressed: _play,
          ),
          const SizedBox(height: AppSpace.lg),
          const AppText('¿Qué sentimiento guarda esta voz?',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.md),
          for (final e in _options) ...[
            ChoiceButton(
              label: e,
              emoji: EmotionStyle.of(e).emoji,
              state: !_answered
                  ? ChoiceState.idle
                  : (e == correct
                      ? ChoiceState.correct
                      : (e == _chosen ? ChoiceState.wrong : ChoiceState.idle)),
              onTap: _answered ? null : () => _answer(e),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          if (_answered) ...[
            const SizedBox(height: AppSpace.sm),
            AppText(
              _chosen == correct
                  ? '¡Sí! Esta voz guarda $correct.'
                  : 'Esta voz guarda $correct.',
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
