import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/backup_service.dart';
import '../../state/memory_provider.dart';

/// Pantalla de copia de seguridad **local y cifrada**: exportar todos los
/// recuerdos a un archivo protegido con contraseña, o restaurarlo.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _defaultFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'senss-copia-${now.year}-${two(now.month)}-${two(now.day)}.senssbak';
  }

  Future<void> _export() async {
    final password = await _askPassword(confirm: true);
    if (password == null || !mounted) return;

    final provider = context.read<MemoryProvider>();
    setState(() => _busy = true);
    try {
      final (bytes, stats) = await provider.createBackup(password);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: _defaultFileName(),
        bytes: bytes,
      );
      if (savedPath == null) {
        _snack('Copia cancelada.');
        return;
      }
      _snack('Copia guardada: ${stats.memories} recuerdos, '
          '${stats.audiographies} audiografías.');
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo crear la copia de seguridad.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final Uint8List? bytes = picked.files.single.bytes;
    if (bytes == null) {
      _snack('No se pudo leer el archivo seleccionado.');
      return;
    }

    if (!await _confirmRestore() || !mounted) return;

    final password = await _askPassword(confirm: false);
    if (password == null || !mounted) return;

    final provider = context.read<MemoryProvider>();
    setState(() => _busy = true);
    try {
      final stats = await provider.restoreBackup(bytes, password);
      _snack('Copia restaurada: ${stats.memories} recuerdos, '
          '${stats.audiographies} audiografías.');
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo restaurar la copia.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text(
          'Se añadirán los recuerdos de la copia a este dispositivo. '
          'Los que ya existan se actualizarán. Nada se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _askPassword({required bool confirm}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(confirm: confirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Guarda todos tus recuerdos y audiografías en un solo archivo '
              'cifrado con contraseña. El archivo se queda en tu dispositivo; '
              'tú eliges dónde guardarlo.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _BackupCard(
              icon: Icons.lock_outline,
              title: 'Crear copia de seguridad',
              subtitle:
                  'Exporta todo a un archivo cifrado (.senssbak) protegido '
                  'con una contraseña que solo tú conoces.',
              buttonLabel: 'Crear copia',
              onPressed: _busy ? null : _export,
            ),
            const SizedBox(height: 16),
            _BackupCard(
              icon: Icons.restore,
              title: 'Restaurar copia',
              subtitle:
                  'Recupera los recuerdos desde un archivo de copia. Se '
                  'fusionan con los actuales; nada se borra.',
              buttonLabel: 'Restaurar',
              onPressed: _busy ? null : _import,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Si olvidas la contraseña no habrá forma de recuperar '
                      'la copia. Guárdala en un lugar seguro.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(
                child: Text('Trabajando…', style: theme.textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _BackupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para introducir (y opcionalmente confirmar) la contraseña.
class _PasswordDialog extends StatefulWidget {
  final bool confirm;
  const _PasswordDialog({required this.confirm});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final pass = _password.text;
    if (pass.isEmpty) {
      setState(() => _error = 'Escribe una contraseña.');
      return;
    }
    if (widget.confirm) {
      if (pass.length < 6) {
        setState(() => _error = 'Usa al menos 6 caracteres.');
        return;
      }
      if (pass != _repeat.text) {
        setState(() => _error = 'Las contraseñas no coinciden.');
        return;
      }
    }
    Navigator.pop(context, pass);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.confirm ? 'Elige una contraseña' : 'Contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => widget.confirm ? null : _submit(),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _repeat,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Repite la contraseña'),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aceptar')),
      ],
    );
  }
}
