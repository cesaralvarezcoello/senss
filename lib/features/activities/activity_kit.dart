import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/models/audiography.dart';
import '../../data/models/memory.dart';
import '../../data/repositories/memory_repository.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';

/// Una "voz" en contexto: la audiografía junto al recuerdo (foto) al que
/// pertenece. Es la unidad de datos que usan las actividades.
typedef Voice = ({Memory memory, Audiography audio});

/// Aplana el feed a la lista de voces con su recuerdo.
List<Voice> voicesOf(List<MemoryWithAudios> feed) => [
      for (final m in feed)
        for (final a in m.audios) (memory: m.memory, audio: a),
    ];

/// Divide "Carlos, tu hijo" en (nombre, relación).
(String, String) splitAuthor(String author) {
  final parts = author.split(',');
  final name = parts.first.trim();
  final rel = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
  return (name.isEmpty ? author.trim() : name, rel);
}

/// Marco común de una actividad: fondo cálido, barra con título y volver.
class ActivityShell extends StatelessWidget {
  final String title;
  final Widget child;
  const ActivityShell({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(title, variant: AppTextVariant.titleL),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

/// Placeholder amable cuando faltan datos para jugar.
class NotEnoughData extends StatelessWidget {
  final String message;
  const NotEnoughData({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: c.accent),
          const SizedBox(height: AppSpace.lg),
          AppText(message,
              variant: AppTextVariant.body,
              tone: AppTone.soft,
              align: TextAlign.center),
        ],
      ),
    );
  }
}

/// Estado visual de una opción de respuesta.
enum ChoiceState { idle, correct, wrong }

/// Botón grande de respuesta (accesible). Se ilumina al revelar.
class ChoiceButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final String? emoji;
  final ChoiceState state;
  final VoidCallback? onTap;

  const ChoiceButton({
    super.key,
    required this.label,
    this.sublabel,
    this.emoji,
    this.state = ChoiceState.idle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color brd, Color ink) = switch (state) {
      ChoiceState.correct => (
          const Color(0xFF2FA36B).withValues(alpha: 0.18),
          const Color(0xFF2FA36B),
          c.ink
        ),
      ChoiceState.wrong => (
          c.danger.withValues(alpha: 0.12),
          c.danger.withValues(alpha: 0.5),
          c.ink
        ),
      ChoiceState.idle => (c.surfaceSoft, c.line, c.ink),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: brd, width: state == ChoiceState.idle ? 1.5 : 2),
          ),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(label,
                        variant: AppTextVariant.titleM, color: ink, maxLines: 1),
                    if (sublabel != null && sublabel!.isNotEmpty)
                      AppText(sublabel!,
                          variant: AppTextVariant.caption,
                          tone: AppTone.soft,
                          maxLines: 1),
                  ],
                ),
              ),
              if (state == ChoiceState.correct)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2FA36B), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celebración cálida (sin puntajes): siempre termina en éxito.
Future<void> showCelebration(
  BuildContext context, {
  required String message,
  String? sub,
  String nextLabel = 'Siguiente',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            AppText(message,
                variant: AppTextVariant.titleL, align: TextAlign.center),
            if (sub != null) ...[
              const SizedBox(height: 8),
              AppText(sub,
                  variant: AppTextVariant.body,
                  tone: AppTone.soft,
                  align: TextAlign.center),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: nextLabel,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Imagen recortada de un recuerdo (para tarjetas de actividad).
Widget memoryThumb(String photoPath,
    {double radius = AppRadius.md, BoxFit fit = BoxFit.cover, Key? key}) {
  return ClipRRect(
    key: key,
    borderRadius: BorderRadius.circular(radius),
    child: RefImage(photoPath, fit: fit),
  );
}

/// Utilidades de azar reproducibles dentro de una sesión.
class Picker {
  final Random _r;
  Picker([int? seed]) : _r = Random(seed);

  T pick<T>(List<T> items) => items[_r.nextInt(items.length)];

  List<T> shuffle<T>(List<T> items) {
    final copy = List<T>.of(items);
    copy.shuffle(_r);
    return copy;
  }

  /// Toma [n] elementos distintos (o menos si no hay suficientes).
  List<T> sample<T>(List<T> items, int n) => shuffle(items).take(n).toList();
}
