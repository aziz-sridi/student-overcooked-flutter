import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/classroom_store.dart';
import '../../data/focus_queue_store.dart';
import '../../data/task_store.dart';
import '../shell/main_shell.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/common/task_sync_status_chip.dart';
import 'task_editor_dialog.dart';

enum _TaskFilter { all, dueSoon, overdue, done }

class SubjectTasksDetailScreen extends StatefulWidget {
  const SubjectTasksDetailScreen({super.key, required this.subject});

  final String subject;

  @override
  State<SubjectTasksDetailScreen> createState() =>
      _SubjectTasksDetailScreenState();
}

class _SubjectTasksDetailScreenState extends State<SubjectTasksDetailScreen> {
  _TaskFilter _selectedFilter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnBack();
        }
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: _showQuickCreate,
          backgroundColor: AppColors.burntOrange,
          foregroundColor: AppColors.white,
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1,
          selectedItemColor: AppColors.burntOrange,
          unselectedItemColor: AppColors.textSecondary,
          onTap: _goToTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_rounded),
              label: 'Focus',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_rounded),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_rounded),
              label: 'Projects',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: _DetailTopBar(
                  title: widget.subject,
                  onBack: _returnBack,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: ValueListenableBuilder<TaskSyncState>(
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
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
              sliver: ValueListenableBuilder<TaskSyncState>(
                valueListenable: TaskStore.instance.syncStateNotifier,
                builder: (context, syncState, _) {
                  return ValueListenableBuilder<List<TaskItem>>(
                    valueListenable: TaskStore.instance.tasksNotifier,
                    builder: (context, tasks, child) {
                      final subjectTasks = TaskStore.instance
                          .tasksForSubject(widget.subject, onlyMine: true)
                          .map(FocusQueueStore.instance.applyFocusState)
                          .toList();
                      final visibleTasks = _filteredAndSortedTasks(
                        subjectTasks,
                      );
                      final projectTasks = visibleTasks
                          .where((task) => task.hasProject)
                          .toList();
                      final classTasks = visibleTasks
                          .where((task) => !task.hasProject)
                          .toList();

                      final showLoading =
                          syncState.status == TaskSyncStatus.loading &&
                          tasks.isEmpty;
                      final showError =
                          syncState.status == TaskSyncStatus.error &&
                          tasks.isEmpty;

                      return SliverList(
                        delegate: SliverChildListDelegate([
                          _SummaryCard(
                            tasks: subjectTasks,
                            onStartFocus: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Focus session started for this subject.',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _FilterRow(
                            selectedFilter: _selectedFilter,
                            onChanged: (filter) =>
                                setState(() => _selectedFilter = filter),
                          ),
                          const SizedBox(height: 10),
                          if (showLoading)
                            const _LoadingState()
                          else if (showError)
                            _SyncErrorState(
                              onRetry: TaskStore.instance.retrySync,
                            )
                          else if (visibleTasks.isEmpty)
                            const _EmptyState()
                          else ...[
                            if (projectTasks.isNotEmpty) ...[
                              _TaskSectionHeader(
                                title: 'Projects',
                                icon: Icons.folder_open_rounded,
                              ),
                              const SizedBox(height: 8),
                              for (final task in projectTasks)
                                _buildTaskItem(task),
                              const SizedBox(height: 8),
                            ],
                            if (classTasks.isNotEmpty) ...[
                              _TaskSectionHeader(
                                title: 'Class',
                                icon: Icons.school_rounded,
                              ),
                              const SizedBox(height: 8),
                              for (final task in classTasks)
                                _buildTaskItem(task),
                            ],
                          ],
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TaskItem> _filteredAndSortedTasks(List<TaskItem> source) {
    final filtered = source.where((task) {
      return switch (_selectedFilter) {
        _TaskFilter.all => true,
        _TaskFilter.dueSoon => task.isDueSoon,
        _TaskFilter.overdue => task.isOverdue,
        _TaskFilter.done => task.isDone,
      };
    }).toList();

    filtered.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
    return filtered;
  }

  Widget _buildTaskItem(TaskItem task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: task.isDone
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await _confirmMarkComplete(task);
        if (confirmed) {
          await _markTaskComplete(task.id);
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.white),
            SizedBox(width: 8),
            Text(
              'Complete',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: TaskCard(
        task: task,
        canEdit: TaskStore.instance.canEdit(task),
        onEdit: () => _editTask(task),
        onEditLocked: () =>
            _showMessage('Only the task owner can edit this task.'),
        onToggleComplete: (done) async => _toggleTask(task.id, done),
        onAddToFocus: () => _addToFocus(task),
        onDelete: () => _confirmDeleteTask(task),
      ),
    );
  }

  Future<void> _toggleTask(String id, bool done) async {
    await TaskStore.instance.setCompletion(id, done);
    FocusQueueStore.instance.markTaskCompletion(id, done);
  }

  Future<void> _markTaskComplete(String id) async {
    await _toggleTask(id, true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Task marked as complete.')));
  }

  Future<bool> _confirmMarkComplete(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.task_alt_rounded, color: AppColors.burntOrange),
        title: const Text('Mark this task complete?'),
        content: Text(
          '“${task.title}” will move to your completed tasks.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _addToFocus(TaskItem task) {
    FocusQueueStore.instance.enqueue(task);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${task.title}" to Focus queue.')),
    );
  }

  Future<void> _editTask(TaskItem task) async {
    if (!TaskStore.instance.canEdit(task)) {
      _showMessage('Only the task owner can edit this task.');
      return;
    }

    final updated = await showTaskEditorDialog(
      context,
      existing: task,
      fixedSubject: widget.subject,
    );
    if (updated == null) {
      return;
    }
    await TaskStore.instance.updateTask(updated);
  }

  void _returnBack() {
    Navigator.of(context).pop();
  }

  void _goToTab(int index) {
    if (index == 1) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(initialTabIndex: index)),
      (route) => false,
    );
  }

  Future<void> _showQuickCreate() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.task_alt_rounded),
                  title: const Text('Create Task'),
                  subtitle: const Text('Add a task for this subject'),
                  onTap: () async {
                    Navigator.pop(context);
                    final created = await showTaskEditorDialog(
                      this.context,
                      fixedSubject: widget.subject,
                    );
                    if (created == null) {
                      return;
                    }
                    await TaskStore.instance.addTask(created);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Create Project'),
                  subtitle: const Text('Add a project workspace'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Project creation flow coming next.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tasks, required this.onStartFocus});

  final List<TaskItem> tasks;
  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((task) => task.isDone).length;
    final closest = tasks.where((task) => !task.isDone).fold<TaskItem?>(null, (
      best,
      task,
    ) {
      if (best == null || task.dueAt.isBefore(best.dueAt)) {
        return task;
      }
      return best;
    });

    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(title: 'Total', value: '$total'),
              const SizedBox(width: 18),
              _Metric(
                title: 'Closest',
                value: closest == null ? 'Done' : closest.deadlineLabel,
                warning:
                    closest?.isOverdue == true || closest?.isDueSoon == true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Progress ${(progress * 100).toStringAsFixed(0)}%',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.progressTrack,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartFocus,
              icon: const Icon(Icons.timer_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                foregroundColor: AppColors.white,
              ),
              label: const Text('Start Focus'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    this.warning = false,
  });

  final String title;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: warning ? AppColors.tomatoRed : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selectedFilter, required this.onChanged});

  final _TaskFilter selectedFilter;
  final ValueChanged<_TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChip(
          label: 'All',
          selected: selectedFilter == _TaskFilter.all,
          onTap: () => onChanged(_TaskFilter.all),
        ),
        _FilterChip(
          label: 'Due Soon',
          selected: selectedFilter == _TaskFilter.dueSoon,
          onTap: () => onChanged(_TaskFilter.dueSoon),
        ),
        _FilterChip(
          label: 'Overdue',
          selected: selectedFilter == _TaskFilter.overdue,
          onTap: () => onChanged(_TaskFilter.overdue),
        ),
        _FilterChip(
          label: 'Done',
          selected: selectedFilter == _TaskFilter.done,
          onTap: () => onChanged(_TaskFilter.done),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TaskSectionHeader extends StatelessWidget {
  const _TaskSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        'No tasks in this filter.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SyncErrorState extends StatelessWidget {
  const _SyncErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.tomatoRed),
          const SizedBox(height: 8),
          Text(
            'Unable to sync this subject right now.',
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
    );
  }
}
