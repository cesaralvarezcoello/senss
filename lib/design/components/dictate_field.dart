import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../tokens.dart';

/// Campo de texto con **dictado por voz** (micrófono). Reconocimiento
/// on-device (Android/iOS/web). Pensado para que las personas no tengan que
/// escribir — clave para usuarios con Alzheimer. Componente centralizado.
class DictateField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  const DictateField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.onChanged,
  });

  @override
  State<DictateField> createState() => _DictateFieldState();
}

class _DictateFieldState extends State<DictateField> {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _listening = false;
  String _base = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'notListening' || s == 'done') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _available = ok);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _base = widget.controller.text;
    setState(() => _listening = true);
    try {
      await _stt.listen(
        onResult: (r) {
          final words = r.recognizedWords;
          final txt = _base.isEmpty ? words : '$_base $words';
          widget.controller.text = txt;
          widget.controller.selection =
              TextSelection.collapsed(offset: txt.length);
          widget.onChanged?.call(txt);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      textCapitalization: widget.capitalization,
      style: const TextStyle(fontSize: 19),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          icon: Icon(
            _listening ? Icons.mic : Icons.mic_none_rounded,
            color: _listening
                ? c.danger
                : (_available ? c.accent : c.inkFaint),
          ),
          tooltip: _available ? 'Dictar' : 'Dictado no disponible',
          onPressed: _available ? _toggle : null,
        ),
      ),
    );
  }
}
