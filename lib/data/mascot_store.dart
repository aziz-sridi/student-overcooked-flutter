import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_store.dart';

enum MascotKind { gigaToast, potato, student }

enum CookedStage { cozy, cooked, crispy, overcooked }

class MascotStore {
  MascotStore._();

  static final MascotStore instance = MascotStore._();
  static const String _key = 'student_overcooked_mascot_v1';
  static const int _seedCoins = 420;

  final ValueNotifier<MascotState> state = ValueNotifier<MascotState>(
    const MascotState(
      kind: MascotKind.potato,
      cookedMeter: 25,
      coinBalance: 0,
      ownedMascots: {MascotKind.potato},
    ),
  );

  bool _initialized = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;
  String? _boundUid;

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

    AuthStore.instance.user.addListener(_handleAuthChanged);
    _handleAuthChanged();

    _initialized = true;
  }

  void _handleAuthChanged() {
    final user = AuthStore.instance.user.value;
    if (user == null) {
      _remoteSub?.cancel();
      _remoteSub = null;
      _boundUid = null;
      return;
    }
    if (_boundUid == user.uid) {
      return;
    }
    _boundUid = user.uid;
    _remoteSub?.cancel();
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    _remoteSub = doc.snapshots().listen((snap) async {
      if (!snap.exists || snap.data() == null) {
        // Seed initial state on first login.
        await doc.set({
          'coinBalance': _seedCoins,
          'ownedMascots': [MascotKind.potato.name],
          'kind': state.value.kind.name,
        }, SetOptions(merge: true));
        return;
      }
      final data = snap.data()!;
      final remoteCoins = (data['coinBalance'] as num?)?.toInt();
      final remoteOwned = (data['ownedMascots'] as List?)
              ?.whereType<String>()
              .map((name) => MascotKind.values
                  .firstWhere((k) => k.name == name, orElse: () => MascotKind.potato))
              .toSet() ??
          state.value.ownedMascots;
      final remoteKind = data['kind'] is String
          ? MascotKind.values.firstWhere(
              (k) => k.name == data['kind'],
              orElse: () => state.value.kind,
            )
          : state.value.kind;
      state.value = state.value.copyWith(
        coinBalance: remoteCoins ?? state.value.coinBalance,
        ownedMascots: remoteOwned.isEmpty ? state.value.ownedMascots : remoteOwned,
        kind: remoteKind,
      );
      await _persistLocal();
    });
  }

  Future<void> setKind(MascotKind kind) async {
    final owned = {...state.value.ownedMascots, kind};
    state.value = state.value.copyWith(kind: kind, ownedMascots: owned);
    await _persist(fields: {'kind': kind.name, 'ownedMascots': owned.map((k) => k.name).toList()});
  }

  Future<void> setCookedMeter(double value) async {
    state.value = state.value.copyWith(cookedMeter: value.clamp(0, 100));
    await _persistLocal();
  }

  Future<void> addCoins(int amount) async {
    final next = (state.value.coinBalance + amount).clamp(0, 999999);
    state.value = state.value.copyWith(coinBalance: next);
    await _persist(fields: {'coinBalance': next});
  }

  Future<void> deductCoins(int amount) async {
    if (state.value.coinBalance >= amount) {
      final next = state.value.coinBalance - amount;
      state.value = state.value.copyWith(coinBalance: next);
      await _persist(fields: {'coinBalance': next});
    }
  }

  Future<void> purchaseMascot(MascotKind kind, int price) async {
    if (state.value.ownedMascots.contains(kind)) {
      await setKind(kind);
      return;
    }
    if (state.value.coinBalance < price) {
      throw StateError('Not enough coins.');
    }
    final next = state.value.coinBalance - price;
    final owned = {...state.value.ownedMascots, kind};
    state.value = state.value.copyWith(
      coinBalance: next,
      ownedMascots: owned,
      kind: kind,
    );
    await _persist(fields: {
      'coinBalance': next,
      'ownedMascots': owned.map((k) => k.name).toList(),
      'kind': kind.name,
    });
  }

  Future<void> _persist({Map<String, dynamic>? fields}) async {
    await _persistLocal();
    final uid = _boundUid;
    if (uid != null && fields != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(fields, SetOptions(merge: true));
      } catch (_) {
        // Offline / permission errors — local state still valid.
      }
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.value.toJson()));
  }
}

class MascotState {
  const MascotState({
    required this.kind,
    required this.cookedMeter,
    this.coinBalance = 0,
    this.ownedMascots = const {MascotKind.potato},
  });

  final MascotKind kind;
  final double cookedMeter;
  final int coinBalance;
  final Set<MascotKind> ownedMascots;

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

  MascotState copyWith({
    MascotKind? kind,
    double? cookedMeter,
    int? coinBalance,
    Set<MascotKind>? ownedMascots,
  }) {
    return MascotState(
      kind: kind ?? this.kind,
      cookedMeter: cookedMeter ?? this.cookedMeter,
      coinBalance: coinBalance ?? this.coinBalance,
      ownedMascots: ownedMascots ?? this.ownedMascots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'cookedMeter': cookedMeter,
      'coinBalance': coinBalance,
      'ownedMascots': ownedMascots.map((k) => k.name).toList(),
    };
  }

  factory MascotState.fromJson(Map<String, dynamic> json) {
    final ownedRaw = json['ownedMascots'];
    Set<MascotKind> owned = {MascotKind.potato};
    if (ownedRaw is List) {
      owned = ownedRaw
          .whereType<String>()
          .map((name) => MascotKind.values
              .firstWhere((k) => k.name == name, orElse: () => MascotKind.potato))
          .toSet();
      if (owned.isEmpty) owned = {MascotKind.potato};
    }
    return MascotState(
      kind: MascotKind.values.firstWhere(
        (item) => item.name == json['kind'],
        orElse: () => MascotKind.potato,
      ),
      cookedMeter: (json['cookedMeter'] as num?)?.toDouble() ?? 25,
      coinBalance: (json['coinBalance'] as int?) ?? 0,
      ownedMascots: owned,
    );
  }
}

String mascotKindLabel(MascotKind kind) {
  return switch (kind) {
    MascotKind.gigaToast => 'Giga Toast',
    MascotKind.potato => 'Potato',
    MascotKind.student => 'Student',
  };
}

String mascotKindAsset(MascotKind kind) {
  final mascot = switch (kind) {
    MascotKind.gigaToast => 'giga_toast',
    MascotKind.potato => 'potato',
    MascotKind.student => 'student',
  };
  return 'assets/mascots/$mascot/cozy.png';
}
