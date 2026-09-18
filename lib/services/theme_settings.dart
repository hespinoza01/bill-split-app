import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste la preferencia de tema (system/light/dark) en SharedPreferences
/// — no es secreto, mismo patrón que ParsingSettings.
class ThemeSettings {
  static const _key = 'theme_mode';

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == stored, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// Estado de tema vivo en memoria — así cambiar la preferencia en Settings
/// repinta la app al toque, sin tener que reiniciarla.
class ThemeModeNotifier extends ChangeNotifier {
  final _settings = ThemeSettings();
  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    mode = await _settings.getThemeMode();
    notifyListeners();
  }

  Future<void> setMode(ThemeMode newMode) async {
    mode = newMode;
    notifyListeners();
    try {
      await _settings.setThemeMode(newMode);
    } catch (_) {
      // No persistió (disco lleno, error de plataforma) — la UI ya cambió
      // de tema igual, solo se pierde la preferencia hasta el próximo
      // intento. No hay nada útil que mostrarle al usuario acá.
    }
  }
}
