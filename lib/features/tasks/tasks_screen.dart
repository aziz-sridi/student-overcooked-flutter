import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/classroom_store.dart';
import '../../data/focus_queue_store.dart';
import '../../data/subject_store.dart';
import '../../data/task_store.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/common/app_top_bar.dart';
import '../../widgets/common/task_sync_status_chip.dart';
import '../shop/shop_screen.dart';
import 'subject_tasks_detail_screen.dart';
import 'task_editor_dialog.dart';

class TasksScreenController {
  VoidCallback? _resetForVisit;

  void resetForVisit() => _resetForVisit?.call();
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.scrollController, this.controller});

  final ScrollController? scrollController;
  final TasksScreenController? controller;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _groupBySubject = true;

  @override
  void initState() {
    super.initState();
    widget.controller?._resetForVisit = _resetForVisit;
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._resetForVisit = null;
      widget.controller?._resetForVisit = _resetForVisit;
    }
  }

  void _resetForVisit() {
    if (!_groupBySubject) {
      setState(() => _groupBySubject = true);
    }
  }

  @override
  void dispose() {
    widget.controller?._resetForVisit = null;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusStore = FocusQueueStore.instance;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickCreate,
        backgroundColor: AppColors.burntOrange,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: AppTopBar(
              title: 'Tasks',
              onShopTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by subject or task',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => _searchController.clear(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      fillColor: AppColors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.cardStroke,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.cardStroke,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Grouped'),
                        selected: _groupBySubject,
                        onSelected: (_) =>
                            setState(() => _groupBySubject = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All Tasks'),
                        selected: !_groupBySubject,
                        onSelected: (_) =>
                            setState(() => _groupBySubject = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<TaskSyncState>(
                    valueListenable: TaskStore.instance.syncStateNotifier,
                    builder: (context, syncState, _) {
                      return Row(
                        children: [
                          TaskSyncStatusChip(
                            state: syncState,
                            onRetry: TaskStore.instance.retrySync,
                          ),
                          if ((syncState.message ?? '').isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                syncState.message!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: ValueListenableBuilder<TaskSyncState>(
              valueListenable: TaskStore.instance.syncStateNotifier,
              builder: (context, syncState, _) {
                return ValueListenableBuilder<List<TaskItem>>(
                  valueListenable: TaskStore.instance.tasksNotifier,
                  builder: (context, storedTasks, _) {
                    return ValueListenableBuilder<List<String>>(
                      valueListenable: SubjectStore.instance.subjects,
                      builder: (context, knownSubjects, _) {
                        final syncedTasks = storedTasks
                            .map(focusStore.applyFocusState)
                            .toList();
                        final filteredTasks = _filterTasks(syncedTasks);
                        final subjects = _buildSubjectSummaries(
                          filteredTasks,
                          knownSubjects,
                        );
                        final sortedFlatTasks = [...filteredTasks]
                          ..sort(
                            (a, b) => b.urgencyScore.compareTo(a.urgencyScore),
                          );

                        final showLoading =
                            syncState.status == TaskSyncStatus.loading &&
                            storedTasks.isEmpty;
                        final showError =
                            syncState.status == TaskSyncStatus.error &&
                            storedTasks.isEmpty;

                        return SliverList.builder(
                          itemCount: showLoading || showError
                              ? 1
                              : _groupBySubject
                              ? (subjects.isEmpty ? 1 : subjects.length)
                              : (sortedFlatTasks.isEmpty
                                    ? 1
                                    : sortedFlatTasks.length),
                          itemBuilder: (context, index) {
                            if (showLoading) {
                              return const _LoadingTaskState();
                            }
                            if (showError) {
                              return _SyncErrorState(
                                onRetry: TaskStore.instance.retrySync,
                              );
                            }

                            if (_groupBySubject && subjects.isEmpty) {
                              return const _EmptyTaskState();
                            }

                            if (_groupBySubject) {
                              final summary = subjects[index];
                              return _SubjectCard(
                                summary: summary,
                                onTap: () => _openSubject(summary.subject),
                                onDelete: () => _confirmDeleteSubject(summary),
                              );
                            }

                            if (sortedFlatTasks.isEmpty) {
                              return const _EmptyTaskState();
                            }

                            final task = sortedFlatTasks[index];
                            return TaskCard(
                              task: task,
                              canEdit: TaskStore.instance.canEdit(task),
                              onEdit: () => _editTask(task),
                              onEditLocked: () => _showSoon(
                                'Only the task owner can edit this task.',
                              ),
                              onToggleComplete: (done) async {
                                await _toggleTask(task.id, done);
                              },
                              onAddToFocus: () => _addToFocus(task),
                              onDelete: () => _confirmDeleteTask(task),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubject(String subject) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SubjectTasksDetailScreen(subject: subject),
      ),
    );
  }

  List<TaskItem> _filterTasks(List<TaskItem> source) {
    // Always limit to tasks assigned to the current user
    final owned = source
        .where((task) => TaskStore.instance.isCurrentUserLabel(task.assignee))
        .toList();

    if (_searchQuery.isEmpty) {
      return owned;
    }
    return owned.where((task) {
      return task.title.toLowerCase().contains(_searchQuery) ||
          task.subject.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<_SubjectSummary> _buildSubjectSummaries(
    List<TaskItem> source,
    List<String> knownSubjects,
  ) {
    final grouped = <String, List<TaskItem>>{};
    for (final task in source) {
      grouped.putIfAbsent(task.subject, () => []).add(task);
    }
    for (final subject in knownSubjects) {
      grouped.putIfAbsent(subject, () => <TaskItem>[]);
    }
    if (_searchQuery.isNotEmpty) {
      grouped.removeWhere(
        (subject, tasks) =>
            tasks.isEmpty && !subject.toLowerCase().contains(_searchQuery),
      );
    }

    final list = grouped.entries
        .map((entry) => _SubjectSummary(subject: entry.key, tasks: entry.value))
        .toList();

    list.sort((a, b) => a.nextDue.difference(b.nextDue).inMinutes);
    return list;
  }

  Future<void> _confirmDeleteSubject(_SubjectSummary summary) async {
    final taskCount = summary.tasks.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete class "${summary.subject}"?'),
        content: Text(
          taskCount == 0
              ? 'This will remove the class from your list.'
              : 'This will remove the class and delete $taskCount task${taskCount == 1 ? '' : 's'} under it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.tomatoRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final task in summary.tasks) {
      await TaskStore.instance.deleteTask(task.id);
      if (task.id.startsWith(ClassroomStore.taskIdPrefix)) {
        await ClassroomStore.instance.untrackAssignment(
          task.id.substring(ClassroomStore.taskIdPrefix.length),
        );
      }
    }
    await SubjectStore.instance.removeSubject(summary.subject);
    await ClassroomStore.instance.untrackCourseByName(summary.subject);
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${task.title}"?'),
        content: const Text('This task will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.tomatoRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await TaskStore.instance.deleteTask(task.id);
    if (task.id.startsWith(ClassroomStore.taskIdPrefix)) {
      await ClassroomStore.instance.untrackAssignment(
        task.id.substring(ClassroomStore.taskIdPrefix.length),
      );
    }
  }

  Future<void> _toggleTask(String id, bool done) async {
    await TaskStore.instance.setCompletion(id, done);
    FocusQueueStore.instance.markTaskCompletion(id, done);
  }

  void _addToFocus(TaskItem task) {
    FocusQueueStore.instance.enqueue(task);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${task.title}" to Focus queue.')),
    );
  }

  Future<void> _editTask(TaskItem task) async {
    if (!TaskStore.instance.canEdit(task)) {
      _showSoon('Only the task owner can edit this task.');
      return;
    }

    final updated = await showTaskEditorDialog(context, existing: task);
    if (updated == null) {
      return;
    }

    await TaskStore.instance.updateTask(updated);
  }

  Future<void> _showQuickCreate() async {
    final created = await showTaskEditorDialog(context);
    if (created == null) {
      return;
    }
    await TaskStore.instance.addTask(created);
  }

  void _showSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SubjectSummary {
  const _SubjectSummary({required this.subject, required this.tasks});

  final String subject;
  final List<TaskItem> tasks;

  int get totalTasks => tasks.length;

  int get projectCount => tasks
      .where((task) => task.hasProject)
      .map((task) => task.projectId)
      .toSet()
      .length;

  DateTime get nextDue {
    final pending = tasks.where((task) => !task.isDone).toList();
    if (pending.isEmpty) {
      return DateTime(2999);
    }
    pending.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return pending.first.dueAt;
  }

  bool get isUrgent {
    if (tasks.every((task) => task.isDone)) {
      return false;
    }
    return tasks.any((task) => task.isOverdue || task.isDueSoon);
  }

  String get nextDueLabel {
    if (tasks.every((task) => task.isDone)) {
      return 'All tasks completed';
    }
    final nearest = tasks.where((task) => !task.isDone).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return nearest.first.deadlineLabel;
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.summary,
    required this.onTap,
    this.onDelete,
  });

  final _SubjectSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: summary.isUrgent
                ? AppColors.tomatoRed.withValues(alpha: 0.28)
                : AppColors.cardStroke,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.totalTasks} task${summary.totalTasks == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: summary.isUrgent
                            ? AppColors.tomatoRed
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          summary.nextDueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: summary.isUrgent
                                    ? AppColors.tomatoRed
                                    : AppColors.textSecondary,
                                fontWeight: summary.isUrgent
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (summary.projectCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusInProgress.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 13,
                      color: AppColors.statusInProgress,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.projectCount}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.statusInProgress,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete class',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.tomatoRed,
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(
          children: [
            Icon(
              Icons.task_alt,
              size: 84,
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No tasks yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first task to get started.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingTaskState extends StatelessWidget {
  const _LoadingTaskState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _SyncErrorState extends StatelessWidget {
  const _SyncErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.tomatoRed,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not sync tasks right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
