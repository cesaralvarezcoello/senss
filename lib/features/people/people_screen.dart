import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models/person.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/dictate_field.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/memory_provider.dart';

/// Gestión de **personas queridas** (familia): nombre, relación y un retrato.
/// Habilita el juego "¿de quién es esta cara?".
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final people = context.watch<MemoryProvider>().people;
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
          title: const AppText('Personas queridas', variant: AppTextVariant.titleL)),
      body: SafeArea(
        child: people.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_rounded, size: 72, color: c.accent),
                      const SizedBox(height: AppSpace.lg),
                      const AppText(
                        'Añade a la familia con su cara y su relación. Así podrán '
                        'jugar a reconocer a los seres queridos.',
                        variant: AppTextVariant.body,
                        tone: AppTone.soft,
                        align: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
                itemBuilder: (_, i) => _PersonTile(person: people[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        onPressed: () => _addPerson(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const AppText('Añadir persona',
            variant: AppTextVariant.label, tone: AppTone.onAccent),
      ),
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddPersonSheet(),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person person;
  const _PersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: person.hasPortrait
                  ? RefImage(person.portraitPath, fit: BoxFit.cover)
                  : ColoredBox(
                      color: c.surfaceSoft,
                      child: Icon(Icons.person, color: c.inkFaint)),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(person.name, variant: AppTextVariant.titleM, maxLines: 1),
                if (person.relationship.isNotEmpty)
                  AppText(person.relationship,
                      variant: AppTextVariant.caption,
                      tone: AppTone.soft,
                      maxLines: 1),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.danger),
            tooltip: 'Eliminar',
            onPressed: () => context.read<MemoryProvider>().deletePerson(person),
          ),
        ],
      ),
    );
  }
}

class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet();

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _rel = TextEditingController();
  Uint8List? _portrait;
  String _ext = 'jpg';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final img = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 88);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        _portrait = bytes;
        _ext = img.name.contains('.') ? img.name.split('.').last.toLowerCase() : 'jpg';
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await context.read<MemoryProvider>().addPerson(
          portraitBytes: _portrait ?? Uint8List(0),
          ext: _ext,
          name: _name.text,
          relationship: _rel.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('Nueva persona', variant: AppTextVariant.titleL),
          const SizedBox(height: AppSpace.lg),
          Center(
            child: GestureDetector(
              onTap: () => _pick(ImageSource.gallery),
              child: ClipOval(
                child: Container(
                  width: 110,
                  height: 110,
                  color: c.surfaceSoft,
                  child: _portrait != null
                      ? Image.memory(_portrait!, fit: BoxFit.cover)
                      : Icon(Icons.add_a_photo_outlined,
                          size: 40, color: c.inkFaint),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Center(
            child: TextButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Usar cámara'),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          DictateField(
            controller: _name,
            label: 'Nombre',
            hint: 'Ej. Carlos',
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.md),
          DictateField(
            controller: _rel,
            label: 'Relación',
            hint: 'Ej. tu hijo',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.xl),
          AppButton(
            label: 'Guardar',
            icon: Icons.check_rounded,
            busy: _busy,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
