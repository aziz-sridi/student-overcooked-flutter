import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';

class SubjectStore {
  SubjectStore._();

  static final SubjectStore instance = SubjectStore._();

  static const String _keyPrefix = 'student_overcooked_subjects_v1';

  final ValueNotifier<List<String>> subjects = ValueNotifier<List<String>>(
    <String>[],
  );

  bool _initialized = false;
  String? _activeUid;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _bindUser(AuthStore.instance.user.value);
    AuthStore.instance.user.addListener(() {
      _bindUser(AuthStore.instance.user.value);
    });
  }

  Future<void> addSubject(String subject) async {
    final updated = _normalizeList(<String>[...subjects.value, subject]);
    subjects.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey(_activeUid), updated);
  }

  Future<void> removeSubject(String subject) async {
    final target = subject.trim().toLowerCase();
    if (target.isEmpty) {
      return;
    }
    final updated = subjects.value
        .where((existing) => existing.trim().toLowerCase() != target)
        .toList();
    subjects.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey(_activeUid), updated);
  }

  Future<void> _bindUser(User? user) async {
    final uid = user?.uid;
    if (_activeUid == uid && subjects.value.isNotEmpty) {
      return;
    }
    _activeUid = uid;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey(uid)) ?? <String>[];
    subjects.value = _normalizeList(stored);
  }

  String _storageKey(String? uid) {
    if (uid == null || uid.isEmpty) {
      return '${_keyPrefix}_anon';
    }
    return '${_keyPrefix}_$uid';
  }

  List<String> _normalizeList(Iterable<String> raw) {
    final seen = <String, String>{};
    for (final entry in raw) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      seen.putIfAbsent(key, () => trimmed);
    }
    final list = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
