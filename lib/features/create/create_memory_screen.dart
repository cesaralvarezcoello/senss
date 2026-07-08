import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../state/memory_provider.dart';

/// Pantalla de creación: importar/tomar una foto, ponerle un título y
/// descripción, y guardarla como recuerdo. La primera audiografía se añade
/// luego desde el feed con el botón del micrófono.
class CreateMemoryScreen extends StatefulWidget {
  const CreateMemoryScreen({super.key});

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (image != null) {
      setState(() => _photoPath = image.path);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (_photoPath == null || title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await context.read<MemoryProvider>().createMemory(
            sourcePhotoPath: _photoPath!,
            title: title,
            description: _descriptionController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ModerationException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo guardar el recuerdo. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _photoPath != null && _titleController.text.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo recuerdo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PhotoPreview(
              photoPath: _photoPath,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(
                labelText: 'Título del recuerdo',
                hintText: 'Ej. Verano en la playa',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: '¿Qué hace especial a este momento?',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Guardando…' : 'Guardar recuerdo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoPreview({
    required this.photoPath,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: photoPath == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 72, color: colors.outline),
                        const SizedBox(height: 8),
                        Text(
                          'Elige una foto',
                          style: TextStyle(
                              fontSize: 18, color: colors.outline),
                        ),
                      ],
                    ),
                  )
                : Image.file(File(photoPath!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCamera,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 26),
                label: const Text('Cámara'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGallery,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 26),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
