import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum TaskPriority { low, medium, high }

enum TaskState { notStarted, inProgress, done }

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueAt,
    required this.priority,
    required this.state,
    this.projectId,
    this.projectTitle,
    this.assignee,
    this.completed = false,
  });

  final String id;
  final String title;
  final String subject;
  final DateTime dueAt;
  final TaskPriority priority;
  final TaskState state;
  final String? projectId;
  final String? projectTitle;
  final String? assignee;
  final bool completed;

  bool get hasProject => projectId != null;

  bool get isDone => state == TaskState.done || completed;

  bool get isOverdue => !isDone && dueAt.isBefore(DateTime.now());

  bool get isDueSoon {
    if (isDone || isOverdue) {
      return false;
    }
    final difference = dueAt.difference(DateTime.now());
    return difference.inHours <= 48;
  }

  int get urgencyScore {
    if (isDone) {
      return -1000;
    }
    if (isOverdue) {
      return 100000;
    }

    final priorityWeight = switch (priority) {
      TaskPriority.high => 300,
      TaskPriority.medium => 200,
      TaskPriority.low => 100,
    };

    final untilDue = dueAt.difference(DateTime.now());
    final hours = untilDue.inHours.clamp(0, 5000);
    return priorityWeight + (5000 - hours);
  }

  String get deadlineLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final dayDiff = dueDay.difference(today).inDays;
    final time = _formatTime(dueAt);

    if (dayDiff == 0) {
      return 'Today, $time';
    }
    if (dayDiff == 1) {
      return 'Tomorrow, $time';
    }
    if (dayDiff == -1) {
      return 'Yesterday, $time';
    }
    return '${_monthName(dueAt.month)} ${dueAt.day}, $time';
  }

  TaskItem copyWith({
    String? title,
    String? subject,
    DateTime? dueAt,
    TaskPriority? priority,
    TaskState? state,
    String? projectId,
    String? projectTitle,
    String? assignee,
    bool? completed,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueAt: dueAt ?? this.dueAt,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      projectId: projectId ?? this.projectId,
      projectTitle: projectTitle ?? this.projectTitle,
      assignee: assignee ?? this.assignee,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'dueAt': dueAt.toIso8601String(),
      'priority': priority.name,
      'state': state.name,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'assignee': assignee,
      'completed': completed,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      state: TaskState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => TaskState.notStarted,
      ),
      projectId: json['projectId'] as String?,
      projectTitle: json['projectTitle'] as String?,
      assignee: json['assignee'] as String?,
      completed: (json['completed'] as bool?) ?? false,
    );
  }

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.tomatoRed;
      case TaskPriority.medium:
        return AppColors.mustardYellow;
      case TaskPriority.low:
        return AppColors.successGreen;
    }
  }

  String get stateLabel {
    switch (state) {
      case TaskState.notStarted:
        return 'Not Started';
      case TaskState.inProgress:
        return 'In Progress';
      case TaskState.done:
        return 'Done';
    }
  }

  Color get stateColor {
    switch (state) {
      case TaskState.notStarted:
        return AppColors.statusNotStarted;
      case TaskState.inProgress:
        return AppColors.statusInProgress;
      case TaskState.done:
        return AppColors.successGreen;
    }
  }

  static String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
