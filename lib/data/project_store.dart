import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/project_item.dart';
import 'auth_store.dart';

class ProjectStore {
  ProjectStore._();

  static final ProjectStore instance = ProjectStore._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<List<ProjectItem>> projectsNotifier =
      ValueNotifier<List<ProjectItem>>(<ProjectItem>[]);

  bool _initialized = false;
  String? _activeUid;
  StreamSubscription? _projectsSubscription;
  VoidCallback? _authListener;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _authListener = () {
      unawaited(_bindUserProjects(AuthStore.instance.user.value));
    };
    AuthStore.instance.user.addListener(_authListener!);
    await _bindUserProjects(AuthStore.instance.user.value);

    _initialized = true;
  }

  Future<void> createProject({
    required String title,
    required String typeLabel,
    String? subject,
  }) async {
    final uid = _activeUid;
    final user = AuthStore.instance.user.value;
    if (uid == null || user == null) {
      throw StateError('You must be signed in to create a project.');
    }

    final memberLabel = _memberLabel(user);
    final inviteCode = _newInviteCode();
    final doc = _firestore.collection('projects').doc();

    final data = {
      'title': title.trim(),
      'typeLabel': typeLabel.trim(),
      'subject': (subject?.trim().isNotEmpty ?? false) ? subject!.trim() : null,
      'createdByUid': uid,
      'memberUids': <String>[uid],
      'memberLabels': <String>[memberLabel],
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await doc.set(data);
  }

  Future<void> joinProjectByInvite(String input) async {
    final uid = _activeUid;
    final user = AuthStore.instance.user.value;
    if (uid == null || user == null) {
      throw StateError('You must be signed in to join a project.');
    }

    final token = _extractInviteToken(input);
    if (token.isEmpty) {
      throw StateError('Enter a valid invite code or invite link.');
    }

    DocumentSnapshot<Map<String, dynamic>>? projectDoc;

    final byCode = await _firestore
        .collection('projects')
        .where('inviteCode', isEqualTo: token)
        .limit(1)
        .get();

    if (byCode.docs.isNotEmpty) {
      projectDoc = byCode.docs.first;
    } else {
      final byId = await _firestore.collection('projects').doc(token).get();
      if (byId.exists) {
        projectDoc = byId;
      }
    }

    if (projectDoc == null || !projectDoc.exists) {
      throw StateError('Project not found for this invite.');
    }

    await projectDoc.reference.update({
      'memberUids': FieldValue.arrayUnion(<String>[uid]),
      'memberLabels': FieldValue.arrayUnion(<String>[_memberLabel(user)]),
    });
  }

  Future<void> _bindUserProjects(User? user) async {
    final uid = user?.uid;
    if (_activeUid == uid && _projectsSubscription != null) {
      return;
    }

    await _projectsSubscription?.cancel();
    _projectsSubscription = null;
    _activeUid = uid;

    if (uid == null) {
      projectsNotifier.value = <ProjectItem>[];
      return;
    }

    _projectsSubscription = _firestore
        .collection('projects')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
          final projects =
              snapshot.docs
                  .map((doc) => ProjectItem.fromFirestore(doc.id, doc.data()))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );
          projectsNotifier.value = projects;
        });
  }

  String _memberLabel(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'Member';
  }

  String _newInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List<String>.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String _extractInviteToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    try {
      final uri = Uri.parse(trimmed);
      final code = uri.queryParameters['code'];
      if (code != null && code.trim().isNotEmpty) {
        return code.trim().toUpperCase();
      }
      final projectId = uri.queryParameters['project'];
      if (projectId != null && projectId.trim().isNotEmpty) {
        return projectId.trim();
      }
    } catch (_) {
      // The input is likely a raw invite code.
    }

    return trimmed.toUpperCase();
  }
}
