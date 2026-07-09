import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/profile.dart';

/// Estado del perfil del usuario (persistido con SharedPreferences, que en web
/// usa localStorage). Notifica a la UI para re-adaptar textos e iconos.
class ProfileStore extends ChangeNotifier {
  static const _key = 'senss_profile';

  Profile _profile = const Profile();
  Profile get profile => _profile;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s != null) {
        _profile = Profile.fromJson(jsonDecode(s) as Map<String, Object?>);
      }
    } catch (_) {
      // Sin plugin (p. ej. en tests) o error: se queda el perfil por defecto.
    }
    notifyListeners();
  }

  Future<void> save(Profile p) async {
    _profile = p;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(p.toJson()));
    } catch (_) {}
  }
}
