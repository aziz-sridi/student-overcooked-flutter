import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

enum SongSourceKind { asset, file }

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.source,
    required this.kind,
  });

  final String id;
  final String title;
  final String source;
  final SongSourceKind kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'kind': kind.name,
      };

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      source: json['source'] as String,
      kind: SongSourceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SongSourceKind.file,
      ),
    );
  }
}

class SongStore {
  SongStore._();

  static final SongStore instance = SongStore._();
  static const _prefsKey = 'student_overcooked_songs_v1';
  static const _assetExtensions = {'.mp3', '.wav', '.ogg', '.m4a', '.aac'};

  final ValueNotifier<List<Song>> songs = ValueNotifier<List<Song>>(const []);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final list = <Song>[];

    // Bundled songs from assets/songs/
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
      for (final path in manifest.keys) {
        if (!path.startsWith('assets/songs/')) continue;
        final lower = path.toLowerCase();
        if (!_assetExtensions.any(lower.endsWith)) continue;
        final name = path.substring('assets/songs/'.length);
        list.add(Song(
          id: 'asset::$path',
          title: _titleFromFile(name),
          source: path,
          kind: SongSourceKind.asset,
        ));
      }
    } catch (_) {
      // ignore
    }

    // Imported songs persisted in prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final song = Song.fromJson(item as Map<String, dynamic>);
          if (song.kind == SongSourceKind.file && !File(song.source).existsSync()) {
            continue;
          }
          list.add(song);
        }
      }
    } catch (_) {
      // ignore
    }

    songs.value = list;
    _initialized = true;
  }

  Future<void> addImportedSong({required String filePath, String? title}) async {
    final cleanTitle = (title ?? _titleFromFile(filePath)).trim();
    final song = Song(
      id: 'file::${DateTime.now().microsecondsSinceEpoch}',
      title: cleanTitle.isEmpty ? 'Imported track' : cleanTitle,
      source: filePath,
      kind: SongSourceKind.file,
    );
    songs.value = [...songs.value, song];
    await _persistImported();
  }

  Future<void> removeSong(String id) async {
    songs.value = songs.value.where((s) => s.id != id).toList();
    await _persistImported();
  }

  Future<void> _persistImported() async {
    final imported =
        songs.value.where((s) => s.kind == SongSourceKind.file).map((s) => s.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(imported));
  }

  String _titleFromFile(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    final filename = segments.isEmpty ? path : segments.last;
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    return base.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  }
}
