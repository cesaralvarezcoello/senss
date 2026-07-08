import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/services/audio_player_service.dart';
import '../../state/memory_provider.dart';
import '../backup/backup_screen.dart';
import '../create/create_memory_screen.dart';
import 'widgets/memory_card.dart';

/// Pantalla principal: un feed vertical de recuerdos, estilo Instagram.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Un único reproductor compartido para todo el feed.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            onPressed: _openBackup,
            icon: const Icon(Icons.shield_outlined, size: 26),
            tooltip: 'Copia de seguridad',
          ),
        ],
      ),
      body: Consumer<MemoryProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.feed.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.feed.isEmpty) {
            return _EmptyState(onCreate: _openCreate);
          }
          return RefreshIndicator(
            onRefresh: provider.loadFeed,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96, top: 4),
              itemCount: provider.feed.length,
              itemBuilder: (context, index) {
                final item = provider.feed[index];
                return MemoryCard(item: item, player: _player);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_a_photo_outlined, size: 26),
        label: const Text(
          'Nuevo recuerdo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, size: 96),
            const SizedBox(height: 24),
            Text(
              'Aún no hay recuerdos',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Añade una foto querida y grábale una audiografía para empezar.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Crear mi primer recuerdo'),
            ),
          ],
        ),
      ),
    );
  }
}
