import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import 'activity_kit.dart';

/// Reto: encuentra las fotos iguales (concentración). Pocas cartas y grandes.
/// Al emparejar suena la voz de ese recuerdo. Sin cronómetro.
class MatchPairsScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const MatchPairsScreen({super.key, required this.feed});

  @override
  State<MatchPairsScreen> createState() => _MatchPairsScreenState();
}

class _Card {
  final String photoPath;
  final String? audioPath;
  final int pairId;
  bool up = false;
  bool matched = false;
  _Card(this.photoPath, this.audioPath, this.pairId);
}

class _MatchPairsScreenState extends State<MatchPairsScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();
  late List<_Card> _cards;
  int? _first;
  bool _busy = false;
  int _matchedPairs = 0;
  late int _pairs;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setup() {
    _pairs = min(3, widget.feed.length);
    final chosen = _picker.sample(widget.feed, _pairs);
    final cards = <_Card>[];
    for (var i = 0; i < chosen.length; i++) {
      final m = chosen[i];
      final audio = m.audios.isNotEmpty ? m.audios.first.audioPath : null;
      cards.add(_Card(m.memory.photoPath, audio, i));
      cards.add(_Card(m.memory.photoPath, audio, i));
    }
    _cards = _picker.shuffle(cards);
    _first = null;
    _busy = false;
    _matchedPairs = 0;
    setState(() {});
  }

  Future<void> _tap(int i) async {
    final card = _cards[i];
    if (_busy || card.up || card.matched) return;
    setState(() => card.up = true);

    if (_first == null) {
      _first = i;
      return;
    }
    final a = _cards[_first!];
    if (a.pairId == card.pairId) {
      // Pareja: se quedan y suena la voz.
      setState(() {
        a.matched = true;
        card.matched = true;
        _matchedPairs++;
      });
      _first = null;
      if (card.audioPath != null) _player.playFile(card.audioPath!);
      if (_matchedPairs == _pairs && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await showCelebration(context,
              message: '¡Las encontraste todas!', nextLabel: 'Jugar otra vez');
          _setup();
        }
      }
    } else {
      // No coinciden: se voltean de nuevo tras una pausa.
      _busy = true;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        a.up = false;
        card.up = false;
        _first = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = _cards.length <= 4 ? 2 : 3;
    return ActivityShell(
      title: 'Encuentra la pareja',
      child: Column(
        children: [
          const AppText('Toca dos fotos iguales',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: GridView.count(
              crossAxisCount: cols,
              mainAxisSpacing: AppSpace.md,
              crossAxisSpacing: AppSpace.md,
              children: [
                for (var i = 0; i < _cards.length; i++)
                  _CardView(card: _cards[i], onTap: () => _tap(i)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  final _Card card;
  final VoidCallback onTap;
  const _CardView({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final showFace = card.up || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: card.matched ? 0.6 : 1,
        duration: AppMotion.fast,
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: showFace
              ? memoryThumb(card.photoPath,
                  radius: AppRadius.md, key: const ValueKey('face'))
              : Container(
                  key: const ValueKey('back'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accent, c.surfaceSoft],
                    ),
                  ),
                  child: Icon(Icons.favorite_rounded,
                      color: c.surface.withValues(alpha: 0.7), size: 32),
                ),
        ),
      ),
    );
  }
}
