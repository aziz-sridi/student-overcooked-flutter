import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MascotKind { gigaToast, potato, student }

enum CookedStage { cozy, cooked, crispy, overcooked }

class MascotStore {
  MascotStore._();

  static final MascotStore instance = MascotStore._();
  static const String _key = 'student_overcooked_mascot_v1';

  final ValueNotifier<MascotState> state = ValueNotifier<MascotState>(
    const MascotState(kind: MascotKind.potato, cookedMeter: 25),
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state.value = MascotState.fromJson(json);
      } catch (_) {
        // Keep default on malformed persisted data.
      }
    }

    _initialized = true;
  }

  Future<void> setKind(MascotKind kind) async {
    state.value = state.value.copyWith(kind: kind);
    await _persist();
  }

  Future<void> setCookedMeter(double value) async {
    state.value = state.value.copyWith(cookedMeter: value.clamp(0, 100));
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.value.toJson()));
  }
}

class MascotState {
  const MascotState({required this.kind, required this.cookedMeter});

  final MascotKind kind;
  final double cookedMeter;

  CookedStage get stage {
    if (cookedMeter < 25) {
      return CookedStage.cozy;
    }
    if (cookedMeter < 55) {
      return CookedStage.cooked;
    }
    if (cookedMeter < 80) {
      return CookedStage.crispy;
    }
    return CookedStage.overcooked;
  }

  String get stageLabel {
    return switch (stage) {
      CookedStage.cozy => 'Cozy',
      CookedStage.cooked => 'Cooked',
      CookedStage.crispy => 'Crispy',
      CookedStage.overcooked => 'Overcooked',
    };
  }

  String get imageAssetPath {
    final mascot = switch (kind) {
      MascotKind.gigaToast => 'giga_toast',
      MascotKind.potato => 'potato',
      MascotKind.student => 'student',
    };
    final file = switch (stage) {
      CookedStage.cozy => 'cozy',
      CookedStage.cooked => 'cooked',
      CookedStage.crispy => 'crispy',
      CookedStage.overcooked => 'overcooked',
    };
    return 'assets/mascots/$mascot/$file.png';
  }

  String get mascotLabel {
    return switch (kind) {
      MascotKind.gigaToast => 'Giga Toast',
      MascotKind.potato => 'Potato',
      MascotKind.student => 'Student',
    };
  }

  MascotState copyWith({MascotKind? kind, double? cookedMeter}) {
    return MascotState(
      kind: kind ?? this.kind,
      cookedMeter: cookedMeter ?? this.cookedMeter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'cookedMeter': cookedMeter,
    };
  }

  factory MascotState.fromJson(Map<String, dynamic> json) {
    return MascotState(
      kind: MascotKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MascotKind.potato,
      ),
      cookedMeter: (json['cookedMeter'] as num?)?.toDouble() ?? 25,
    );
  }
}
