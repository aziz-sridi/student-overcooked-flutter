import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/project_item.dart';
import '../models/quick_stat_item.dart';
import '../models/task_item.dart';

const quickStats = [
  QuickStatItem(
    label: 'Tasks',
    value: '12/18',
    icon: Icons.task_alt,
    iconColor: AppColors.burntOrange,
  ),
  QuickStatItem(
    label: 'Overdue',
    value: '2',
    icon: Icons.warning_amber_rounded,
    iconColor: AppColors.tomatoRed,
  ),
  QuickStatItem(
    label: 'Streak',
    value: '6 days',
    icon: Icons.local_fire_department,
    iconColor: AppColors.mustardYellow,
  ),
  QuickStatItem(
    label: 'Focus',
    value: '3h 20m',
    icon: Icons.timer,
    iconColor: AppColors.successGreen,
  ),
];

final allTasks = [
  TaskItem(
    id: 't1',
    title: 'Finalize software design report',
    subject: 'Software Engineering',
    dueAt: DateTime(2026, 4, 17, 23, 59),
    priority: TaskPriority.high,
    state: TaskState.inProgress,
    projectId: 'p1',
    projectTitle: 'Student Overcooked Mobile App',
    assignee: 'You',
  ),
  TaskItem(
    id: 't2',
    title: 'Review database normalization notes',
    subject: 'Database Systems',
    dueAt: DateTime(2026, 4, 18, 10, 0),
    priority: TaskPriority.medium,
    state: TaskState.notStarted,
    assignee: 'You',
  ),
  TaskItem(
    id: 't3',
    title: 'Prepare UI flow for project demo',
    subject: 'Mobile Development',
    dueAt: DateTime(2026, 4, 15, 14, 0),
    priority: TaskPriority.low,
    state: TaskState.done,
    completed: true,
    projectId: 'p1',
    projectTitle: 'Student Overcooked Mobile App',
    assignee: 'Member 2',
  ),
  TaskItem(
    id: 't4',
    title: 'Implement group chat bubble redesign',
    subject: 'Team Project',
    dueAt: DateTime(2026, 4, 20, 18, 0),
    priority: TaskPriority.high,
    state: TaskState.notStarted,
    projectId: 'p1',
    projectTitle: 'Student Overcooked Mobile App',
    assignee: null,
  ),
  TaskItem(
    id: 't5',
    title: 'Submit sprint retrospective',
    subject: 'Software Engineering',
    dueAt: DateTime(2026, 4, 16, 21, 0),
    priority: TaskPriority.high,
    state: TaskState.notStarted,
    projectId: 'p1',
    projectTitle: 'Student Overcooked Mobile App',
    assignee: 'You',
  ),
  TaskItem(
    id: 't6',
    title: 'Unit test parser edge cases',
    subject: 'Compiler Design',
    dueAt: DateTime(2026, 4, 14, 12, 30),
    priority: TaskPriority.medium,
    state: TaskState.notStarted,
    projectId: 'p2',
    projectTitle: 'Compiler Assignment Toolkit',
    assignee: 'Member 2',
  ),
];

final workNowTasks = [
  TaskItem(
    id: 'w1',
    title: 'Finalize software design report',
    subject: 'Software Engineering',
    dueAt: DateTime(2026, 4, 17, 23, 59),
    priority: TaskPriority.high,
    state: TaskState.inProgress,
    projectId: 'p1',
    projectTitle: 'Student Overcooked Mobile App',
  ),
  TaskItem(
    id: 'w2',
    title: 'Review database normalization notes',
    subject: 'Database Systems',
    dueAt: DateTime(2026, 4, 18, 10, 0),
    priority: TaskPriority.medium,
    state: TaskState.notStarted,
  ),
];

const projects = [
  ProjectItem(
    id: 'p1',
    title: 'Student Overcooked Mobile App',
    typeLabel: 'Team Project',
    completedTasks: 9,
    totalTasks: 14,
    teamCount: 4,
  ),
  ProjectItem(
    id: 'p2',
    title: 'Compiler Assignment Toolkit',
    typeLabel: 'Individual',
    completedTasks: 6,
    totalTasks: 10,
    teamCount: 1,
  ),
  ProjectItem(
    id: 'p3',
    title: 'Data Viz Case Study',
    typeLabel: 'Team Project',
    completedTasks: 3,
    totalTasks: 8,
    teamCount: 3,
  ),
];
