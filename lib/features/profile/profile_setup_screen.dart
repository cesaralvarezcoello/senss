import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/profile.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/dictate_field.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';

/// Configura el perfil de la persona: nombre, edad y género. Estas opciones
/// adaptan textos, tamaños e iconos en toda la app (de forma centralizada).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _name;
  late AgeGroup _age;
  late Gender _gender;
  late bool _memory;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileStore>().profile;
    _name = TextEditingController(text: p.name);
    _age = p.age;
    _gender = p.gender;
    _memory = p.memorySupport;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ProfileStore>();
    await store.save(
      store.profile.copyWith(
        name: _name.text.trim(),
        age: _age,
        gender: _gender,
        configured: true,
        memorySupport: _memory,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Perfil', variant: AppTextVariant.titleL)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppText(
              'Con estos datos senss adapta los textos, el tamaño de letra y los '
              'juegos a la persona.',
              variant: AppTextVariant.body,
              tone: AppTone.soft,
            ),
            const SizedBox(height: AppSpace.xl),
            const AppText('¿Cómo se llama?', variant: AppTextVariant.titleM),
            const SizedBox(height: AppSpace.sm),
            DictateField(
              controller: _name,
              hint: 'Ej. Rosa',
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpace.xl),
            const AppText('¿Tiene Alzheimer o problemas de memoria?',
                variant: AppTextVariant.titleM),
            const SizedBox(height: AppSpace.xs),
            const AppText(
              'Nos ayuda a cuidarla mejor. No se comparte con nadie.',
              variant: AppTextVariant.caption,
              tone: AppTone.soft,
            ),
            const SizedBox(height: AppSpace.md),
            _AgeCard(
              label: 'Sí',
              hint: 'senss se simplifica al máximo y prioriza la conversación',
              selected: _memory,
              onTap: () => setState(() => _memory = true),
            ),
            const SizedBox(height: AppSpace.sm),
            _AgeCard(
              label: 'No',
              hint: 'Uso general',
              selected: !_memory,
              onTap: () => setState(() => _memory = false),
            ),
            const SizedBox(height: AppSpace.xl),
            const AppText('Edad', variant: AppTextVariant.titleM),
            const SizedBox(height: AppSpace.md),
            _AgeCard(
              label: 'Tercera edad',
              hint: 'Todo más grande y sencillo',
              selected: _age == AgeGroup.senior,
              onTap: () => setState(() => _age = AgeGroup.senior),
            ),
            const SizedBox(height: AppSpace.sm),
            _AgeCard(
              label: 'Adulto',
              hint: 'Equilibrado',
              selected: _age == AgeGroup.adult,
              onTap: () => setState(() => _age = AgeGroup.adult),
            ),
            const SizedBox(height: AppSpace.sm),
            _AgeCard(
              label: 'Joven',
              hint: 'Más ágil y con más reto',
              selected: _age == AgeGroup.young,
              onTap: () => setState(() => _age = AgeGroup.young),
            ),
            const SizedBox(height: AppSpace.xl),
            const AppText('Género', variant: AppTextVariant.titleM),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              children: [
                _GenderChip(
                  label: 'Mujer',
                  selected: _gender == Gender.female,
                  onTap: () => setState(() => _gender = Gender.female),
                ),
                _GenderChip(
                  label: 'Hombre',
                  selected: _gender == Gender.male,
                  onTap: () => setState(() => _gender = Gender.male),
                ),
                _GenderChip(
                  label: 'Prefiero no decir',
                  selected: _gender == Gender.unspecified,
                  onTap: () => setState(() => _gender = Gender.unspecified),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxl),
            AppButton(label: 'Guardar', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _AgeCard extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  const _AgeCard(
      {required this.label,
      required this.hint,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.accent.withValues(alpha: 0.14) : c.surfaceSoft,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: selected ? c.accent : c.line, width: selected ? 2 : 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(label, variant: AppTextVariant.titleM),
                    AppText(hint, variant: AppTextVariant.caption, tone: AppTone.soft),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: c.accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: AppText(label,
            variant: AppTextVariant.label,
            color: selected ? c.onAccent : c.ink),
      ),
    );
  }
}
