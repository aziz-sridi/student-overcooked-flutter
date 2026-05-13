import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task_item.dart';
import 'auth_store.dart';
import 'mock_data.dart';

enum TaskSyncStatus { loading, syncing, synced, offline, error }

class TaskSyncState {
  const TaskSyncState({
    required this.status,
    this.message,
    this.errorCode,
  });

  final TaskSyncStatus status;
  final String? message;
  final String? errorCode;
}

class TaskStore {
  TaskStore._();

  static final TaskStore instance = TaskStore._();

  static const String currentUser = 'You';

  final ValueNotifier<List<TaskItem>> tasksNotifier = ValueNotifier<List<TaskItem>>([]);
  final ValueNotifier<TaskSyncState> syncStateNotifier = ValueNotifier<TaskSyncState>(
    const TaskSyncState(status: TaskSyncStatus.loading),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  StreamSubscription? _tasksSubscription;
  VoidCallback? _authListener;
  String? _activeUid;
  bool _lastSnapshotFromCache = false;
  bool _lastSnapshotHasPendingWrites = false;
  int _pendingMutations = 0;
  final Map<String, TaskItem> _serverTasksById = <String, TaskItem>{};
  final Map<String, TaskItem> _unsyncedTasksById = <String, TaskItem>{};
  String? _lastSyncErrorCode;

  List<TaskItem> get tasks => tasksNotifier.value;

  List<TaskItem> get workNowTasks {
    final items = tasks
        .where((task) => task.assignee == currentUser && !task.hasProject)
        .toList()
      ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return items.take(3).toList();
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _authListener = () {
      unawaited(_bindUserTasks(AuthStore.instance.user.value));
    };
    AuthStore.instance.user.addListener(_authListener!);
    _setSyncState(const TaskSyncState(status: TaskSyncStatus.loading));
    await _bindUserTasks(AuthStore.instance.user.value);

    _initialized = true;
  }

  List<TaskItem> tasksForProject(String projectId) {
    final list = tasks.where((task) => task.projectId == projectId).toList();
    list.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return list;
  }

  List<TaskItem> tasksForSubject(String subject, {bool onlyMine = false}) {
    final list = tasks
        .where((task) => task.subject == subject)
        .where((task) => !onlyMine || task.assignee == currentUser)
        .toList();
    list.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return list;
  }

  bool canEdit(TaskItem task, {String user = currentUser}) {
    if (!task.hasProject) {
      return true;
    }
    return task.assignee == user;
  }

  Future<void> addTask(TaskItem task) async {
    final normalized = _normalizeOwnership(task);
    await _persistTask(normalized);
  }

  Future<void> updateTask(TaskItem updated) async {
    final normalized = _normalizeOwnership(updated);
    await _persistTask(normalized);
  }

  Future<void> claimTask(String taskId, {String user = currentUser}) async {
    final existing = _findTaskById(taskId);
    if (existing == null) {
      return;
    }
    await _persistTask(existing.copyWith(assignee: user));
  }

  Future<void> setCompletion(String taskId, bool done) async {
    final existing = _findTaskById(taskId);
    if (existing == null) {
      return;
    }
    await _persistTask(
      existing.copyWith(
        state: done ? TaskState.done : TaskState.notStarted,
        completed: done,
      ),
    );
  }

  Future<void> reset() async {
    final seeded = _seedInitialTasks();
    final uid = _activeUid;
    if (uid == null) {
      return;
    }

    _unsyncedTasksById
      ..clear()
      ..addEntries(seeded.map((task) {
        final normalized = _normalizeOwnership(task);
        return MapEntry(normalized.id, normalized);
      }));
    _publishVisibleTasks();

    _pendingMutations += 1;
    _setSyncState(const TaskSyncState(status: TaskSyncStatus.syncing));
    try {
      final snapshot = await _taskCollection(uid).get();
      final clearBatch = _firestore.batch();
      for (final doc in snapshot.docs) {
        clearBatch.delete(doc.reference);
      }
      await clearBatch.commit();

      final seedBatch = _firestore.batch();
      for (final task in seeded) {
        final normalized = _normalizeOwnership(task);
        seedBatch.set(_taskCollection(uid).doc(normalized.id), _toFirestore(normalized));
      }
      await seedBatch.commit();
      _unsyncedTasksById.clear();
      _lastSyncErrorCode = null;
    } catch (error) {
      _lastSyncErrorCode = _extractErrorCode(error);
      _setSyncState(
        TaskSyncState(
          status: TaskSyncStatus.error,
          message: 'Saved locally. Could not sync reset yet.',
          errorCode: _lastSyncErrorCode,
        ),
      );
    } finally {
      if (_pendingMutations > 0) {
        _pendingMutations -= 1;
      }
      _publishVisibleTasks();
      _refreshSyncState();
    }
  }

  Future<void> retrySync() async {
    final uid = _activeUid;
    if (uid != null && _unsyncedTasksById.isNotEmpty) {
      _setSyncState(const TaskSyncState(status: TaskSyncStatus.syncing));
      final pending = List<TaskItem>.from(_unsyncedTasksById.values);
      for (final task in pending) {
        try {
          await _taskCollection(uid).doc(task.id).set(_toFirestore(task));
          _unsyncedTasksById.remove(task.id);
        } catch (error) {
          _lastSyncErrorCode = _extractErrorCode(error);
          // Keep task in unsynced map for next retry.
        }
      }
      _publishVisibleTasks();
      _refreshSyncState();
    }
    _setSyncState(const TaskSyncState(status: TaskSyncStatus.loading));
    await _bindUserTasks(AuthStore.instance.user.value);
  }

  Future<void> _bindUserTasks(User? user) async {
    final uid = user?.uid;
    if (_activeUid == uid && _tasksSubscription != null) {
      return;
    }

    await _tasksSubscription?.cancel();
    _tasksSubscription = null;
    _activeUid = uid;
    _lastSnapshotFromCache = false;
    _lastSnapshotHasPendingWrites = false;
    _pendingMutations = 0;
    _serverTasksById.clear();
    _unsyncedTasksById.clear();
    _lastSyncErrorCode = null;

    if (uid == null) {
      _publishVisibleTasks();
      _setSyncState(const TaskSyncState(status: TaskSyncStatus.synced));
      return;
    }

    _setSyncState(const TaskSyncState(status: TaskSyncStatus.loading));
    _tasksSubscription = _taskCollection(uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        if (snapshot.docs.isEmpty && !snapshot.metadata.isFromCache) {
          unawaited(_seedIfEmpty(uid));
        }
        final serverItems = snapshot.docs
            .map(_fromFirestore)
            .map(_normalizeOwnership)
            .toList();
        _serverTasksById
          ..clear()
          ..addEntries(serverItems.map((task) => MapEntry(task.id, task)));

        final ackedIds = <String>[];
        for (final entry in _unsyncedTasksById.entries) {
          final serverVersion = _serverTasksById[entry.key];
          if (serverVersion != null && _sameTask(serverVersion, entry.value)) {
            ackedIds.add(entry.key);
          }
        }
        for (final id in ackedIds) {
          _unsyncedTasksById.remove(id);
        }

        _publishVisibleTasks();
        _lastSnapshotFromCache = snapshot.metadata.isFromCache;
        _lastSnapshotHasPendingWrites = snapshot.metadata.hasPendingWrites;
        _refreshSyncState();
      },
      onError: (error) {
        _lastSyncErrorCode = _extractErrorCode(error);
        _setSyncState(
          TaskSyncState(
            status: TaskSyncStatus.error,
            message: 'Could not sync tasks. Retrying when network is back.',
            errorCode: _lastSyncErrorCode,
          ),
        );
      },
    );
  }

  CollectionReference<Map<String, dynamic>> _taskCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  Future<void> _seedIfEmpty(String uid) async {
    try {
      final exists = await _taskCollection(uid).limit(1).get();
      if (exists.docs.isNotEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final task in _seedInitialTasks()) {
        final normalized = _normalizeOwnership(task);
        batch.set(_taskCollection(uid).doc(normalized.id), _toFirestore(normalized));
      }
      await batch.commit();
    } catch (_) {
      // Keep app usable even if initial seeding fails due transient network or rules.
    }
  }

  TaskSyncStatus _deriveStatus({
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    if (_pendingMutations > 0 || hasPendingWrites) {
      return TaskSyncStatus.syncing;
    }
    if (_unsyncedTasksById.isNotEmpty) {
      return TaskSyncStatus.error;
    }
    if (isFromCache) {
      return TaskSyncStatus.offline;
    }
    return TaskSyncStatus.synced;
  }

  void _setSyncState(TaskSyncState state) {
    syncStateNotifier.value = state;
  }

  Future<void> _persistTask(TaskItem task) async {
    final uid = _activeUid;
    if (uid == null) {
      _setSyncState(
        const TaskSyncState(
          status: TaskSyncStatus.error,
          message: 'Sign in required before syncing tasks.',
        ),
      );
      return;
    }

    final normalized = _normalizeOwnership(task);
    _unsyncedTasksById[normalized.id] = normalized;
    _publishVisibleTasks();

    _pendingMutations += 1;
    _setSyncState(const TaskSyncState(status: TaskSyncStatus.syncing));
    try {
      await _taskCollection(uid).doc(normalized.id).set(_toFirestore(normalized));
      _unsyncedTasksById.remove(normalized.id);
      _lastSyncErrorCode = null;
    } catch (error) {
      _lastSyncErrorCode = _extractErrorCode(error);
      _setSyncState(
        TaskSyncState(
          status: TaskSyncStatus.error,
          message: 'Saved locally. Will sync when connection or rules allow.',
          errorCode: _lastSyncErrorCode,
        ),
      );
    } finally {
      if (_pendingMutations > 0) {
        _pendingMutations -= 1;
      }
      _publishVisibleTasks();
      _refreshSyncState();
    }
  }

  void _refreshSyncState() {
    final status = _deriveStatus(
      isFromCache: _lastSnapshotFromCache,
      hasPendingWrites: _lastSnapshotHasPendingWrites,
    );
    if (_unsyncedTasksById.isEmpty) {
      _lastSyncErrorCode = null;
    }
    final message = _unsyncedTasksById.isNotEmpty
        ? 'Unsynced changes are kept locally. Tap Retry when ready.'
        : _lastSnapshotFromCache
            ? 'You are viewing cached tasks.'
            : null;
    _setSyncState(
      TaskSyncState(
        status: status,
        message: message,
        errorCode: _lastSyncErrorCode,
      ),
    );
  }

  void _publishVisibleTasks() {
    final merged = <String, TaskItem>{}
      ..addAll(_serverTasksById)
      ..addAll(_unsyncedTasksById);
    final items = merged.values.toList()
      ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    tasksNotifier.value = items;
  }

  TaskItem? _findTaskById(String id) {
    return _unsyncedTasksById[id] ?? _serverTasksById[id];
  }

  bool _sameTask(TaskItem a, TaskItem b) {
    return a.title == b.title &&
        a.subject == b.subject &&
        a.dueAt.toIso8601String() == b.dueAt.toIso8601String() &&
        a.priority == b.priority &&
        a.state == b.state &&
        a.projectId == b.projectId &&
        a.projectTitle == b.projectTitle &&
        a.assignee == b.assignee &&
        a.completed == b.completed;
  }

  String? _extractErrorCode(Object error) {
    if (error is FirebaseException) {
      return error.code;
    }
    return error.runtimeType.toString();
  }

  Map<String, dynamic> _toFirestore(TaskItem task) {
    final normalized = _normalizeOwnership(task);
    return {
      'title': normalized.title,
      'subject': normalized.subject,
      'dueAt': Timestamp.fromDate(normalized.dueAt),
      'priority': normalized.priority.name,
      'state': normalized.state.name,
      'projectId': normalized.projectId,
      'projectTitle': normalized.projectTitle,
      'assignee': normalized.assignee,
      'completed': normalized.completed,
    };
  }

  TaskItem _fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final json = Map<String, dynamic>.from(doc.data());
    final dueAt = json['dueAt'];
    if (dueAt is Timestamp) {
      json['dueAt'] = dueAt.toDate().toIso8601String();
    }
    json['id'] = doc.id;
    return _normalizeOwnership(TaskItem.fromJson(json));
  }

  TaskItem _normalizeOwnership(TaskItem task) {
    if (!task.hasProject && (task.assignee == null || task.assignee!.isEmpty)) {
      return task.copyWith(assignee: currentUser);
    }
    return task;
  }

  List<TaskItem> _seedInitialTasks() {
    return allTasks.map((task) {
      if (task.assignee != null) {
        return task;
      }
      if (!task.hasProject) {
        return task.copyWith(assignee: currentUser);
      }
      return task;
    }).toList();
  }
}
