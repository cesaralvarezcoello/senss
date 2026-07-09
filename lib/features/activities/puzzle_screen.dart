import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import 'activity_kit.dart';

/// Reto: recompón la foto querida. Toca dos piezas para intercambiarlas. Al
/// completar, suena la voz del recuerdo. Sin cronómetro; dificultad ajustable.
class PuzzleScreen extends StatefulWidget {
  final List<MemoryWithAudios> feed;
  const PuzzleScreen({super.key, required this.feed});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();

  late MemoryWithAudios _memory;
  int _n = 3;
  late List<int> _order; // order[slot] = pieza original
  int? _selected;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _setup(newPhoto: true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setup({bool newPhoto = false}) {
    if (newPhoto) _memory = _picker.pick(widget.feed);
    final count = _n * _n;
    do {
      _order = _picker.shuffle(List.generate(count, (i) => i));
    } while (_isSolved(_order));
    _selected = null;
    _solved = false;
    setState(() {});
  }

  bool _isSolved(List<int> o) {
    for (var i = 0; i < o.length; i++) {
      if (o[i] != i) return false;
    }
    return true;
  }

  Future<void> _tap(int slot) async {
    if (_solved) return;
    if (_selected == null) {
      setState(() => _selected = slot);
      return;
    }
    if (_selected == slot) {
      setState(() => _selected = null);
      return;
    }
    setState(() {
      final tmp = _order[_selected!];
      _order[_selected!] = _order[slot];
      _order[slot] = tmp;
      _selected = null;
    });
    if (_isSolved(_order)) {
      setState(() => _solved = true);
      if (_memory.audios.isNotEmpty) {
        _player.playFile(_memory.audios.first.audioPath);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        await showCelebration(context,
            message: '¡Lo lograste!',
            sub: _memory.memory.title,
            nextLabel: 'Otra foto');
        _setup(newPhoto: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ActivityShell(
      title: 'Rompecabezas',
      child: Column(
        children: [
          const AppText('Toca dos piezas para intercambiarlas',
              variant: AppTextVariant.body, tone: AppTone.soft),
          const SizedBox(height: AppSpace.md),
          // Selector de dificultad, muy simple.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DiffChip(label: 'Fácil', active: _n == 2, onTap: () {
                _n = 2;
                _setup();
              }),
              const SizedBox(width: AppSpace.sm),
              _DiffChip(label: 'Más', active: _n == 3, onTap: () {
                _n = 3;
                _setup();
              }),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, cons) {
                final board = min(cons.maxWidth, cons.maxHeight);
                return Center(
                  child: Container(
                    width: board,
                    height: board,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: c.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var r = 0; r < _n; r++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < _n; col++)
                                  Expanded(
                                    child: _cell(r * _n + col, board),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int slot, double board) {
    final original = _order[slot];
    final selected = _selected == slot;
    return GestureDetector(
      onTap: () => _tap(slot),
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? context.colors.accent
                : Colors.white.withValues(alpha: 0.35),
            width: selected ? 3 : 1,
          ),
        ),
        child: _piece(original, board),
      ),
    );
  }

  Widget _piece(int original, double board) {
    final col = original % _n;
    final row = original ~/ _n;
    final ax = _n == 1 ? 0.0 : (col / (_n - 1)) * 2 - 1;
    final ay = _n == 1 ? 0.0 : (row / (_n - 1)) * 2 - 1;
    return ClipRect(
      child: OverflowBox(
        minWidth: board,
        maxWidth: board,
        minHeight: board,
        maxHeight: board,
        alignment: Alignment(ax, ay),
        child: SizedBox(
          width: board,
          height: board,
          child: Image.file(File(_memory.memory.photoPath), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DiffChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? c.accent : c.line),
        ),
        child: AppText(label,
            variant: AppTextVariant.label,
            color: active ? c.onAccent : c.inkSoft),
      ),
    );
  }
}
