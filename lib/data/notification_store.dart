import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStore {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const _key = 'student_overcooked_notifications_v1';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_key) ?? true;
    _initialized = true;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
