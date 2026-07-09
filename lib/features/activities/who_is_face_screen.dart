import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/person.dart';
import '../../design/components/app_button.dart';
import '../../design/components/app_text.dart';
import '../../design/components/ref_image.dart';
import '../../design/tokens.dart';
import '../../state/profile_store.dart';
import 'activity_kit.dart';

/// Reto: mira una cara querida y elige quién es. Refuerza el reconocimiento de
/// los seres queridos. Nº de opciones según la edad del perfil. Sin fallo.
class WhoIsFaceScreen extends StatefulWidget {
  final List<Person> people;
  const WhoIsFaceScreen({super.key, required this.people});

  @override
  State<WhoIsFaceScreen> createState() => _WhoIsFaceScreenState();
}

class _WhoIsFaceScreenState extends State<WhoIsFaceScreen> {
  final _picker = Picker();
  late final List<Person> _people;
  late final int _choices;

  late Person _target;
  late List<Person> _options;
  bool _answered = false;
  String? _chosenId;

  @override
  void initState() {
    super.initState();
    _people = widget.people.where((p) => p.hasPortrait).toList();
    _choices = context.read<ProfileStore>().profile.choiceCount;
    _newRound();
  }

  void _newRound() {
    _target = _picker.pick(_people);
    final others = _people.where((p) => p.id != _target.id).toList();
    _options = _picker.shuffle([
      _target,
      ..._picker.sample(others, _choices - 1),
    ]);
    _answered = false;
    _chosenId = null;
    setState(() {});
  }

  void _answer(Person p) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _chosenId = p.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: '¿De quién es esta cara?',
      child: ListView(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: SizedBox(
                width: 240,
                height: 240,
                child: RefImage(_target.portraitPath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const AppText('¿Sabes quién es?',
              variant: AppTextVariant.body,
              tone: AppTone.soft,
              align: TextAlign.center),
          const SizedBox(height: AppSpace.lg),
          for (final p in _options) ...[
            ChoiceButton(
              label: p.name,
              sublabel: p.relationship,
              state: !_answered
                  ? ChoiceState.idle
                  : (p.id == _target.id
                      ? ChoiceState.correct
                      : (p.id == _chosenId ? ChoiceState.wrong : ChoiceState.idle)),
              onTap: _answered ? null : () => _answer(p),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          if (_answered) ...[
            const SizedBox(height: AppSpace.sm),
            AppText(
              _chosenId == _target.id
                  ? '¡Muy bien! Es ${_target.name}'
                      '${_target.relationship.isEmpty ? '' : ', ${_target.relationship}'}.'
                  : 'Es ${_target.name}'
                      '${_target.relationship.isEmpty ? '' : ', ${_target.relationship}'}.',
              variant: AppTextVariant.bodyStrong,
              align: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: 'Otra cara',
              icon: Icons.arrow_forward_rounded,
              onPressed: _newRound,
            ),
          ],
        ],
      ),
    );
  }
}
