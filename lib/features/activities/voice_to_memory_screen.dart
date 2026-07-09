import 'package:flutter/material.dart';

import '../../data/models/memory.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import 'activity_kit.dart';

/// Reto: suena una voz; ¿a qué foto (recuerdo) pertenece? Une la voz con su
/// momento. Sin fallo: se revela la foto correcta con cariño.
class VoiceToMemoryScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const VoiceToMemoryScreen({super.key, required this.feed});

  @override
  State<VoiceToMemoryScreen> createState() => _VoiceToMemoryScreenState();
}

class _VoiceToMemoryScreenState extends State<VoiceToMemoryScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  late final List<Voice> _voices;
  late final List<Memory> _memories;

  late Voice _target;
  late List<Memory> _options;
  bool _answered = false;
  String? _chosenId;

  @override
  void initState() {
    super.initState();
    _voices = voicesOf(widget.feed);
    _memories = widget.feed.map((m) => m.memory).toList();
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
        _memories.where((m) => m.id != _target.memory.id).toList();
    _options = _picker.shuffle([
      _target.memory,
      ..._picker.sample(others, 2),
    ]);
    _answered = false;
    _chosenId = null;
    setState(() {});
    _play();
  }

  void _play() => _player.playFile(_target.audio.audioPath);

  void _answer(Memory m) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _chosenId = m.id;
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final (name, _) = splitAuthor(_target.audio.authorName);

    return ActivityShell(
      title: '¿A qué recuerdo pertenece?',
      child: ListView(
        children: [
          AppText('Escucha a $name y toca la foto de ese recuerdo',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: 'Escuchar de nuevo',
            icon: Icons.volume_up_rounded,
            variant: AppButtonVariant.tonal,
            onPressed: _play,
          ),
          const SizedBox(height: AppSpace.xl),
          for (final m in _options) ...[
            _PhotoOption(
              memory: m,
              state: !_answered
                  ? ChoiceState.idle
                  : (m.id == _target.memory.id
                      ? ChoiceState.correct
                      : (m.id == _chosenId
                          ? ChoiceState.wrong
                          : ChoiceState.idle)),
              onTap: _answered ? null : () => _answer(m),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          if (_answered) ...[
            const SizedBox(height: AppSpace.sm),
            AppText(
              _chosenId == _target.memory.id
                  ? '¡Muy bien! Es "${_target.memory.title}".'
                  : 'Es "${_target.memory.title}".',
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

class _PhotoOption extends StatelessWidget {
  final Memory memory;
  final ChoiceState state;
  final VoidCallback? onTap;
  const _PhotoOption({required this.memory, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brd = switch (state) {
      ChoiceState.correct => const Color(0xFF2FA36B),
      ChoiceState.wrong => c.danger,
      ChoiceState.idle => c.line,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: brd, width: state == ChoiceState.idle ? 1.5 : 3),
        ),
        padding: const EdgeInsets.all(4),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              memoryThumb(memory.photoPath, radius: AppRadius.md),
              if (state == ChoiceState.correct)
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2FA36B), size: 30),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
