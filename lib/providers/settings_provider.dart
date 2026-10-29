// lib/providers/settings_provider.dart
// Preferencias del teléfono (no de la cuenta): tema y modo de la app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema elegido: sigue al sistema (por defecto), siempre claro o siempre oscuro.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      state = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

/// Cómo se usa la app: pasajero (por defecto) o conductor, como el
/// interruptor de InDrive. Se recuerda en el teléfono.
enum AppMode { passenger, driver }

class AppModeNotifier extends StateNotifier<AppMode> {
  AppModeNotifier() : super(AppMode.passenger) {
    _load();
  }

  static const key = 'app_mode_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(key) == AppMode.driver.name) state = AppMode.driver;
    } catch (_) {}
  }

  Future<void> set(AppMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode.name);
    } catch (_) {}
  }
}

final appModeProvider =
    StateNotifierProvider<AppModeNotifier, AppMode>((ref) => AppModeNotifier());
