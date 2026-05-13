import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore {
  ThemeStore._();

  static final ThemeStore instance = ThemeStore._();

  static const _key = 'student_overcooked_theme_v1';

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      mode.value = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
    _initialized = true;
  }

  Future<void> set(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (newMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_key, raw);
  }
}
