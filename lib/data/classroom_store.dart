import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item.dart';
import 'auth_store.dart';
import 'subject_store.dart';
import 'task_store.dart';

const String _webGoogleClientId =
    '888637651520-4115251u0gqb3sd7b5a2vrgqtq0kigkm.apps.googleusercontent.com';

class ClassroomCourse {
  const ClassroomCourse({required this.id, required this.name, this.section});

  final String id;
  final String name;
  final String? section;
}

class ClassroomAssignment {
  const ClassroomAssignment({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    this.dueAt,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final DateTime? dueAt;

  String get dueLabel {
    if (dueAt == null) {
      return 'No due date';
    }
    final month = dueAt!.month.toString().padLeft(2, '0');
    final day = dueAt!.day.toString().padLeft(2, '0');
    final hour = dueAt!.hour.toString().padLeft(2, '0');
    final minute = dueAt!.minute.toString().padLeft(2, '0');
    return '${dueAt!.year}-$month-$day $hour:$minute';
  }
}

class ClassroomState {
  const ClassroomState({
    required this.isLoading,
    required this.isConnected,
    required this.courses,
    required this.assignments,
    required this.importedCourseIds,
    required this.importedAssignmentIds,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isConnected;
  final List<ClassroomCourse> courses;
  final List<ClassroomAssignment> assignments;
  final Set<String> importedCourseIds;
  final Set<String> importedAssignmentIds;
  final String? errorMessage;

  ClassroomState copyWith({
    bool? isLoading,
    bool? isConnected,
    List<ClassroomCourse>? courses,
    List<ClassroomAssignment>? assignments,
    Set<String>? importedCourseIds,
    Set<String>? importedAssignmentIds,
    String? errorMessage,
  }) {
    return ClassroomState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      courses: courses ?? this.courses,
      assignments: assignments ?? this.assignments,
      importedCourseIds: importedCourseIds ?? this.importedCourseIds,
      importedAssignmentIds:
          importedAssignmentIds ?? this.importedAssignmentIds,
      errorMessage: errorMessage,
    );
  }

  factory ClassroomState.signedOut() {
    return const ClassroomState(
      isLoading: false,
      isConnected: false,
      courses: <ClassroomCourse>[],
      assignments: <ClassroomAssignment>[],
      importedCourseIds: <String>{},
      importedAssignmentIds: <String>{},
    );
  }
}

class ClassroomStore {
  ClassroomStore._();

  static final ClassroomStore instance = ClassroomStore._();

  final ValueNotifier<ClassroomState> state = ValueNotifier<ClassroomState>(
    ClassroomState.signedOut(),
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webGoogleClientId : null,
    scopes: [
      'email',
      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
    ],
  );

  GoogleSignInAccount? _account;
  bool _initialized = false;
  String? _activeUid;

  static const String _courseIdsKeyPrefix =
      'student_overcooked_classroom_courses_v1';
  static const String _assignmentIdsKeyPrefix =
      'student_overcooked_classroom_assignments_v1';
  static const String _taskIdPrefix = 'gc_';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _loadImportedIds();
    AuthStore.instance.user.addListener(() {
      unawaited(_handleAuthChanged());
    });
    await _handleAuthChanged();
  }

  Future<void> _handleAuthChanged() async {
    await _loadImportedIds();
    if (AuthStore.instance.user.value == null) {
      _account = null;
      state.value = _signedOutState();
      return;
    }
    await refresh();
  }

  Future<void> _loadImportedIds() async {
    final uid = AuthStore.instance.user.value?.uid;
    _activeUid = uid;
    final prefs = await SharedPreferences.getInstance();
    final courseIds =
        (prefs.getStringList(_courseStorageKey(uid)) ?? <String>[]).toSet();
    final assignmentIds =
        (prefs.getStringList(_assignmentStorageKey(uid)) ?? <String>[]).toSet();
    state.value = state.value.copyWith(
      importedCourseIds: courseIds,
      importedAssignmentIds: assignmentIds,
    );
  }

  String _courseStorageKey(String? uid) =>
      '${_courseIdsKeyPrefix}_${uid ?? 'anon'}';
  String _assignmentStorageKey(String? uid) =>
      '${_assignmentIdsKeyPrefix}_${uid ?? 'anon'}';

  Future<void> connect() async {
    _setLoading(true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state.value = _signedOutState(
          message:
              'Connection cancelled. Your existing tasks were not changed.',
        );
        return;
      }
      _account = account;
      await _refreshWithAccount(account);
    } catch (error) {
      _setError(error.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // The local Classroom session is cleared even if Google is unreachable.
      }
    } finally {
      _account = null;
      state.value = _signedOutState();
    }
  }

  Future<void> clearSession() async {
    await disconnect();
  }

  Future<void> refresh() async {
    _setLoading(true);
    try {
      _account ??= await _googleSignIn.signInSilently();
      if (_account == null) {
        state.value = _signedOutState();
        return;
      }
      await _refreshWithAccount(_account!);
    } on _ClassroomApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        try {
          final refreshed = await _googleSignIn.signInSilently(
            reAuthenticate: true,
          );
          if (refreshed != null) {
            _account = refreshed;
            await _refreshWithAccount(refreshed);
            return;
          }
        } catch (_) {
          // Fall through to the reconnect state below.
        }
        _account = null;
        state.value = _signedOutState(
          message:
              'Your Classroom session expired. Reconnect to continue syncing.',
        );
      } else {
        _setError(error.message);
      }
    } catch (error) {
      _setError(
        'Could not refresh Classroom. Check your connection and try again.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _refreshWithAccount(GoogleSignInAccount account) async {
    final headers = await account.authHeaders;
    final courses = await _fetchCourses(headers);
    final assignments = <ClassroomAssignment>[];

    for (final course in courses) {
      assignments.addAll(await _fetchAssignments(course, headers));
    }

    assignments.sort((a, b) {
      final aDue = a.dueAt ?? DateTime(9999);
      final bDue = b.dueAt ?? DateTime(9999);
      return aDue.compareTo(bDue);
    });

    state.value = ClassroomState(
      isLoading: false,
      isConnected: true,
      courses: courses,
      assignments: assignments,
      importedCourseIds: state.value.importedCourseIds,
      importedAssignmentIds: state.value.importedAssignmentIds,
    );
  }

  ClassroomState _signedOutState({String? message}) {
    return ClassroomState.signedOut().copyWith(
      importedCourseIds: state.value.importedCourseIds,
      importedAssignmentIds: state.value.importedAssignmentIds,
      errorMessage: message,
    );
  }

  Future<void> untrackCourseByName(String name) async {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return;
    final current = state.value;
    final matchingIds = current.courses
        .where((c) => c.name.trim().toLowerCase() == target)
        .map((c) => c.id)
        .toSet();
    if (matchingIds.isEmpty) return;
    final updated = current.importedCourseIds.difference(matchingIds);
    if (updated.length == current.importedCourseIds.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_courseStorageKey(_activeUid), updated.toList());
    state.value = current.copyWith(importedCourseIds: updated);
  }

  Future<void> untrackAssignment(String assignmentId) async {
    final current = state.value;
    if (!current.importedAssignmentIds.contains(assignmentId)) return;
    final updated = {...current.importedAssignmentIds}..remove(assignmentId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _assignmentStorageKey(_activeUid),
      updated.toList(),
    );
    state.value = current.copyWith(importedAssignmentIds: updated);
  }

  static const String taskIdPrefix = _taskIdPrefix;

  Future<void> applyImports({
    required Set<String> courseIds,
    required Set<String> assignmentIds,
  }) async {
    final current = state.value;
    final previousCourses = current.importedCourseIds;
    final previousAssignments = current.importedAssignmentIds;

    final coursesById = {for (final c in current.courses) c.id: c};
    final assignmentsById = {for (final a in current.assignments) a.id: a};

    final coursesToAdd = courseIds.difference(previousCourses);
    final coursesToRemove = previousCourses.difference(courseIds);
    final assignmentsToAdd = assignmentIds.difference(previousAssignments);
    final assignmentsToRemove = previousAssignments.difference(assignmentIds);

    for (final id in coursesToAdd) {
      final course = coursesById[id];
      if (course != null) {
        await SubjectStore.instance.addSubject(course.name);
      }
    }
    for (final id in coursesToRemove) {
      final course = coursesById[id];
      if (course != null) {
        await SubjectStore.instance.removeSubject(course.name);
      }
    }

    for (final id in assignmentsToAdd) {
      final assignment = assignmentsById[id];
      if (assignment == null) continue;
      await TaskStore.instance.addTask(
        TaskItem(
          id: '$_taskIdPrefix$id',
          title: assignment.title,
          subject: assignment.courseName,
          dueAt:
              assignment.dueAt ?? DateTime.now().add(const Duration(days: 7)),
          priority: TaskPriority.medium,
          state: TaskState.notStarted,
        ),
      );
    }
    for (final id in assignmentsToRemove) {
      await TaskStore.instance.deleteTask('$_taskIdPrefix$id');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _courseStorageKey(_activeUid),
      courseIds.toList(),
    );
    await prefs.setStringList(
      _assignmentStorageKey(_activeUid),
      assignmentIds.toList(),
    );

    state.value = current.copyWith(
      importedCourseIds: courseIds,
      importedAssignmentIds: assignmentIds,
    );
  }

  Future<List<ClassroomCourse>> _fetchCourses(
    Map<String, String> headers,
  ) async {
    final attempts = <Uri>[
      Uri.parse(
        'https://classroom.googleapis.com/v1/courses'
        '?studentId=me&courseStates=ACTIVE&courseStates=PROVISIONED',
      ),
      Uri.parse('https://classroom.googleapis.com/v1/courses?studentId=me'),
      Uri.parse('https://classroom.googleapis.com/v1/courses'),
    ];

    final seen = <String, ClassroomCourse>{};
    String? lastError;

    for (final uri in attempts) {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw _ClassroomApiException(
            response.statusCode,
            'Google Classroom needs to be reconnected.',
          );
        }
        lastError =
            'Classroom courses request failed (${response.statusCode}): ${response.body}';
        continue;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawCourses = data['courses'] as List<dynamic>? ?? const <dynamic>[];
      for (final entry in rawCourses) {
        final json = entry as Map<String, dynamic>;
        final id = (json['id'] as String?) ?? '';
        if (id.isEmpty || seen.containsKey(id)) {
          continue;
        }
        seen[id] = ClassroomCourse(
          id: id,
          name: (json['name'] as String?) ?? 'Untitled Course',
          section: json['section'] as String?,
        );
      }
      if (seen.isNotEmpty) {
        return seen.values.toList();
      }
    }

    if (seen.isEmpty && lastError != null) {
      throw _ClassroomApiException(0, lastError);
    }
    return seen.values.toList();
  }

  Future<List<ClassroomAssignment>> _fetchAssignments(
    ClassroomCourse course,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse(
      'https://classroom.googleapis.com/v1/courses/${course.id}/courseWork?courseWorkStates=PUBLISHED',
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw _ClassroomApiException(
          response.statusCode,
          'Google Classroom needs to be reconnected.',
        );
      }
      return <ClassroomAssignment>[];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawAssignments =
        data['courseWork'] as List<dynamic>? ?? const <dynamic>[];

    return rawAssignments
        .map((entry) {
          final json = entry as Map<String, dynamic>;
          return ClassroomAssignment(
            id: (json['id'] as String?) ?? '',
            courseId: course.id,
            courseName: course.name,
            title: (json['title'] as String?) ?? 'Untitled Assignment',
            dueAt: _parseDueDate(json),
          );
        })
        .where((assignment) => assignment.id.isNotEmpty)
        .toList();
  }

  DateTime? _parseDueDate(Map<String, dynamic> json) {
    final dueDate = json['dueDate'];
    if (dueDate is! Map<String, dynamic>) {
      return null;
    }

    final year = dueDate['year'] as int?;
    final month = dueDate['month'] as int?;
    final day = dueDate['day'] as int?;
    if (year == null || month == null || day == null) {
      return null;
    }

    final dueTime = json['dueTime'];
    final hours = dueTime is Map<String, dynamic>
        ? (dueTime['hours'] as int? ?? 0)
        : 0;
    final minutes = dueTime is Map<String, dynamic>
        ? (dueTime['minutes'] as int? ?? 0)
        : 0;
    final seconds = dueTime is Map<String, dynamic>
        ? (dueTime['seconds'] as int? ?? 0)
        : 0;

    return DateTime(year, month, day, hours, minutes, seconds);
  }

  void _setLoading(bool value) {
    state.value = state.value.copyWith(
      isLoading: value,
      errorMessage: value ? null : state.value.errorMessage,
    );
  }

  void _setError(String message) {
    state.value = state.value.copyWith(
      isLoading: false,
      isConnected: _account != null,
      errorMessage: message,
    );
  }
}

class _ClassroomApiException implements Exception {
  const _ClassroomApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
