import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// **Ordena tu historia** — inspirado en los juegos de secuencia (tipo Zip /
/// Crossclimb), pero con tus fotos: colócalas de la más antigua a la más nueva.
/// Refuerza la orientación en el tiempo. Sin fallo: si no coincide, senss muestra
/// con cariño cómo fue, y al terminar suena una voz querida.
class TimelineScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const TimelineScreen({super.key, required this.feed});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();

  late List<MemoryWithAudios> _items; // orden correcto (por fecha)
  late List<MemoryWithAudios> _pool; // barajadas, por colocar
  final List<MemoryWithAudios> _placed = [];
  bool _done = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _newRound() {
    final n = (context.read<ProfileStore>().profile.choiceCount + 1)
        .clamp(3, widget.feed.length)
        .toInt();
    final chosen = _picker.sample(widget.feed, n);
    _items = List.of(chosen)
      ..sort((a, b) => a.memory.createdAt.compareTo(b.memory.createdAt));
    _pool = _picker.shuffle(chosen);
    _placed.clear();
    _done = false;
    _correct = false;
    setState(() {});
  }

  void _place(MemoryWithAudios m) {
    if (_done) return;
    setState(() {
      _pool.remove(m);
      _placed.add(m);
    });
    if (_pool.isEmpty) _evaluate();
  }

  void _undo() {
    if (_done || _placed.isEmpty) return;
    setState(() => _pool.add(_placed.removeLast()));
  }

  void _evaluate() {
    var ok = true;
    for (var i = 0; i < _items.length; i++) {
      if (_placed[i].memory.id != _items[i].memory.id) {
        ok = false;
        break;
      }
    }
    setState(() {
      _correct = ok;
      _done = true;
    });
    final first = _items.first;
    if (first.audios.isNotEmpty) _player.playFile(first.audios.first.audioPath);
  }

  @override
  Widget build(BuildContext context) {
    // Al fallar, se revela el orden correcto; si acierta, se queda su orden.
    final shown = _done && !_correct ? _items : _placed;
    return ActivityShell(
      title: 'Ordena tu historia',
      child: ListView(
        children: [
          AppText(
            _done
                ? (_correct
                    ? '¡Así fue tu historia! 💛'
                    : 'Así ocurrió, de la más antigua a la más nueva:')
                : 'Toca las fotos de la más antigua a la más nueva.',
            variant: AppTextVariant.body,
            tone: AppTone.soft,
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (var i = 0; i < shown.length; i++)
                _NumberedThumb(
                    index: i + 1, photoPath: shown[i].memory.photoPath),
            ],
          ),
          if (!_done) ...[
            const SizedBox(height: AppSpace.xl),
            if (_pool.isNotEmpty)
              const AppText('Elige la siguiente:',
                  variant: AppTextVariant.titleM),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final m in _pool)
                  GestureDetector(
                    onTap: () => _place(m),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: memoryThumb(m.memory.photoPath),
                    ),
                  ),
              ],
            ),
            if (_placed.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              AppButton(
                label: 'Deshacer',
                icon: Icons.undo_rounded,
                variant: AppButtonVariant.tonal,
                onPressed: _undo,
              ),
            ],
          ],
          if (_done) ...[
            const SizedBox(height: AppSpace.xl),
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

class _NumberedThumb extends StatelessWidget {
  final int index;
  final String photoPath;
  const _NumberedThumb({required this.index, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(child: memoryThumb(photoPath)),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppText('$index',
                  variant: AppTextVariant.label, color: c.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}
