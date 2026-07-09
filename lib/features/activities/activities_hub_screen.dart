import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/memory_repository.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import 'activity_kit.dart';
import 'emotion_guess_screen.dart';
import 'match_pairs_screen.dart';
import 'puzzle_screen.dart';
import 'tell_me_screen.dart';
import 'voice_to_memory_screen.dart';
import 'who_is_it_screen.dart';

/// Modo "Juntos": actividades de reminiscencia que la familia hace con la
/// persona. Sin cronómetros ni puntajes; cada una termina con la voz querida.
class ActivitiesHubScreen extends StatelessWidget {
  const ActivitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<MemoryProvider>().feed;
    final voices = voicesOf(feed);
    final authors = voices.map((v) => v.audio.authorName).toSet();
    final withEmotion = voices.where((v) => v.audio.emotionTag != null);

    final activities = <_Activity>[
      _Activity(
        icon: Icons.record_voice_over_rounded,
        color: const Color(0xFFE5484D),
        title: '¿De quién es esta voz?',
        subtitle: 'Reconocer a los seres queridos',
        enabled: authors.length >= 2,
        need: 'Graba voces de al menos 2 personas.',
        builder: () => WhoIsItScreen(feed: feed),
      ),
      _Activity(
        icon: Icons.extension_rounded,
        color: const Color(0xFFF5A524),
        title: 'Rompecabezas',
        subtitle: 'Recomponer una foto querida',
        enabled: feed.isNotEmpty,
        need: 'Añade al menos un recuerdo con foto.',
        builder: () => PuzzleScreen(feed: feed),
      ),
      _Activity(
        icon: Icons.style_rounded,
        color: const Color(0xFF12A594),
        title: 'Encuentra la pareja',
        subtitle: 'Emparejar fotos iguales',
        enabled: feed.length >= 2,
        need: 'Añade al menos 2 recuerdos.',
        builder: () => MatchPairsScreen(feed: feed),
      ),
      _Activity(
        icon: Icons.favorite_rounded,
        color: const Color(0xFFE93D82),
        title: 'Adivina la emoción',
        subtitle: '¿Qué sentimiento guarda esta voz?',
        enabled: withEmotion.isNotEmpty,
        need: 'Graba voces con una emoción asignada.',
        builder: () => EmotionGuessScreen(feed: feed),
      ),
      _Activity(
        icon: Icons.image_search_rounded,
        color: const Color(0xFF3E63DD),
        title: '¿A qué recuerdo pertenece?',
        subtitle: 'Unir la voz con su foto',
        enabled: feed.length >= 2 && voices.isNotEmpty,
        need: 'Añade 2 recuerdos y alguna voz.',
        builder: () => VoiceToMemoryScreen(feed: feed),
      ),
      _Activity(
        icon: Icons.mic_rounded,
        color: const Color(0xFF8E4EC6),
        title: 'Cuéntame de este día',
        subtitle: 'Grabar un recuerdo propio',
        enabled: feed.isNotEmpty,
        need: 'Añade al menos un recuerdo.',
        builder: () => TellMeScreen(feed: feed),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const AppText('Juntos', variant: AppTextVariant.titleL)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: AppText(
                'Actividades para hacer juntos, sin prisa. Cada una termina con '
                'una voz querida.',
                variant: AppTextVariant.body,
                tone: AppTone.soft,
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpace.md,
              crossAxisSpacing: AppSpace.md,
              childAspectRatio: 0.86,
              children: [
                for (final a in activities) _ActivityCard(activity: a),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Activity {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final String need;
  final Widget Function() builder;
  const _Activity({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.need,
    required this.builder,
  });
}

class _ActivityCard extends StatelessWidget {
  final _Activity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = activity;
    return Opacity(
      opacity: a.enabled ? 1 : 0.5,
      child: Material(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: a.enabled
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => a.builder()),
                  )
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(a.need)),
                  ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: c.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: a.color.withValues(alpha: 0.16),
                  ),
                  child: Icon(a.icon, color: a.color, size: 28),
                ),
                const Spacer(),
                AppText(a.title, variant: AppTextVariant.titleM, maxLines: 2),
                const SizedBox(height: 4),
                AppText(a.subtitle,
                    variant: AppTextVariant.caption,
                    tone: AppTone.soft,
                    maxLines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
