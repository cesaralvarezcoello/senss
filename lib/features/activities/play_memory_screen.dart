import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profile.dart';
import '../../data/repositories/memory_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// "Arma tu recuerdo": un recuerdo concreto se vuelve un rompecabezas de su
/// foto. La dificultad depende del perfil (edad). Al armarlo se revela la foto
/// y suena la voz; y se aprovecha para **completar un dato que falte** (p. ej.
/// la descripción). Es la actividad tejida al navegar los recuerdos.
class PlayMemoryScreen extends StatefulWidget {
  final MemoryWithAudios item;
  const PlayMemoryScreen({super.key, required this.item});

  @override
  State<PlayMemoryScreen> createState() => _PlayMemoryScreenState();
}

class _PlayMemoryScreenState extends State<PlayMemoryScreen> {
  final _picker = Picker();
  final _player = AudioPlayerService();

  late int _n; // tamaño de la cuadrícula, según la edad
  late List<int> _order;
  int? _selected;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _n = switch (context.read<ProfileStore>().profile.age) {
      AgeGroup.senior => 2,
      AgeGroup.adult => 3,
      AgeGroup.young => 4,
    };
    _shuffle();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _shuffle() {
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
    if (_isSolved(_order)) await _onSolved();
  }

  Future<void> _onSolved() async {
    setState(() => _solved = true);
    final audios = widget.item.audios;
    if (audios.isNotEmpty) {
      _player.playSequence(audios.map((a) => a.audioPath).toList());
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await showCelebration(context,
        message: '¡Armaste el recuerdo!',
        sub: widget.item.memory.title,
        nextLabel: 'Seguir');

    // Aprovecha para completar un dato que falte (la descripción).
    if (mounted &&
        (widget.item.memory.description == null ||
            widget.item.memory.description!.trim().isEmpty)) {
      await _completeDescription();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _completeDescription() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Qué recuerdas de este día?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
              hintText: 'Escribe algo bonito de este momento…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty && mounted) {
      await context
          .read<MemoryProvider>()
          .updateMemory(widget.item.memory.copyWith(description: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ActivityShell(
      title: 'Arma tu recuerdo',
      child: Column(
        children: [
          const AppText('Toca dos piezas para intercambiarlas y arma la foto',
              variant: AppTextVariant.body,
              tone: AppTone.soft,
              align: TextAlign.center),
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
                                  Expanded(child: _cell(r * _n + col, board)),
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
          child: RefImage(widget.item.memory.photoPath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
