import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/services/audio_player_service.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';
import '../activities/activities_hub_screen.dart';
import '../backup/backup_screen.dart';
import '../create/create_memory_screen.dart';
import '../dev/sample_data.dart';
import '../people/people_screen.dart';
import '../profile/profile_setup_screen.dart';
import 'widgets/memory_card.dart';

/// Pantalla principal: un feed vertical y cálido de recuerdos.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final AudioPlayerService _player = AudioPlayerService();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateMemoryScreen()),
    );
  }

  void _openBackup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  void _openActivities() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivitiesHubScreen()),
    );
  }

  bool _seeding = false;
  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await seedSampleData(context.read<MemoryProvider>());
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const AppText('senss', variant: AppTextVariant.titleL),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PeopleScreen())),
            icon: const Icon(Icons.groups_outlined, size: 26),
            tooltip: 'Personas',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProfileSetupScreen())),
            icon: const Icon(Icons.person_outline, size: 26),
            tooltip: 'Perfil',
          ),
          IconButton(
            onPressed: _openActivities,
            icon: const Icon(Icons.celebration_outlined, size: 26),
            tooltip: 'Actividades juntos',
          ),
          IconButton(
            onPressed: _openBackup,
            icon: const Icon(Icons.shield_outlined, size: 26),
            tooltip: 'Copia de seguridad',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<MemoryProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.feed.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.feed.isEmpty) {
            return _EmptyState(
                onCreate: _openCreate, onSeed: _seed, seeding: _seeding);
          }
          return RefreshIndicator(
            color: c.accent,
            onRefresh: provider.loadFeed,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 110),
              itemCount: provider.feed.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const _FeedHeader();
                final item = provider.feed[index - 1];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpace.xl),
                  child: MemoryCard(item: item, player: _player),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.add_a_photo_outlined, size: 24),
        label: const AppText(
          'Nuevo recuerdo',
          variant: AppTextVariant.label,
          tone: AppTone.onAccent,
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Tus recuerdos', variant: AppTextVariant.display),
          SizedBox(height: 6),
          AppText(
            'Fotos y voces que se quedan contigo.',
            variant: AppTextVariant.body,
            tone: AppTone.soft,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onSeed;
  final bool seeding;
  const _EmptyState(
      {required this.onCreate, required this.onSeed, required this.seeding});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.14),
              ),
              child: Icon(Icons.photo_library_outlined,
                  size: 60, color: c.accent),
            ),
            const SizedBox(height: AppSpace.xl),
            const AppText(
              'Aún no hay recuerdos',
              variant: AppTextVariant.titleL,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.md),
            const AppText(
              'Añade una foto querida y grábale una voz para empezar.',
              variant: AppTextVariant.body,
              tone: AppTone.soft,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(
              label: 'Crear mi primer recuerdo',
              icon: Icons.add_a_photo_outlined,
              expand: false,
              onPressed: onCreate,
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: 'Cargar ejemplos',
              icon: Icons.auto_awesome_rounded,
              variant: AppButtonVariant.ghost,
              expand: false,
              busy: seeding,
              onPressed: onSeed,
            ),
          ],
        ),
      ),
    );
  }
}
