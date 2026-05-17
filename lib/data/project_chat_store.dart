import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_store.dart';

class ProjectChatMessage {
  const ProjectChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderLabel,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String senderLabel;
  final String text;
  final DateTime createdAt;

  factory ProjectChatMessage.fromFirestore(
    String id,
    Map<String, dynamic> json,
  ) {
    final createdAt = json['createdAt'];
    return ProjectChatMessage(
      id: id,
      senderUid: (json['senderUid'] as String?) ?? '',
      senderLabel: (json['senderLabel'] as String?) ?? 'Member',
      text: (json['text'] as String?) ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ProjectChatStore {
  ProjectChatStore._();

  static final ProjectChatStore instance = ProjectChatStore._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ProjectChatMessage>> messagesForProject(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProjectChatMessage.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> sendMessage({
    required String projectId,
    required String text,
  }) async {
    final user = AuthStore.instance.user.value;
    if (user == null) {
      throw StateError('You must be signed in to send messages.');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final data = <String, dynamic>{
      'text': trimmed,
      'senderUid': user.uid,
      'senderLabel': _memberLabel(user),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .add(data);
  }

  Future<void> sendAiMessage({
    required String projectId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .add({
      'text': trimmed,
      'senderUid': 'ai',
      'senderLabel': 'AI',
      'createdAt': FieldValue.serverTimestamp(),
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
}
