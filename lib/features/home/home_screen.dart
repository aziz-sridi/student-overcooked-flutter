import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/focus_queue_store.dart';
import '../../data/mascot_store.dart';
import '../../data/task_store.dart';
import '../../models/quick_stat_item.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/quick_stat_card.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';
import '../tasks/task_editor_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickCreate(context),
        backgroundColor: AppColors.burntOrange,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: AppTopBar(
                title: 'Student Overcooked',
                onShopTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _CookedMeterCard(),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Quick Stats'),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<List<TaskItem>>(
                    valueListenable: TaskStore.instance.tasksNotifier,
                    builder: (context, tasks, _) {
                      final stats = _buildQuickStats(_ownedTasks(tasks));
                      return SizedBox(
                        height: 142,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: stats.length,
                          itemBuilder: (context, index) =>
                              QuickStatCard(item: stats[index]),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Work Now', actionText: 'View All'),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<List<TaskItem>>(
                    valueListenable: TaskStore.instance.tasksNotifier,
                    builder: (context, tasksValue, child) {
                      final tasks = TaskStore.instance.workNowTasks;
                      if (tasks.isEmpty) {
                        return Text(
                          'No tasks yet. Add your first quick task.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        );
                      }

                      return Column(
                        children: [
                          for (final task in tasks)
                            TaskCard(
                              task: FocusQueueStore.instance.applyFocusState(task),
                              compact: true,
                              canEdit: TaskStore.instance.canEdit(task),
                              onEdit: () => _editTask(context, task),
                              onEditLocked: () => _showMessage(
                                context,
                                'Only the task owner can edit this task.',
                              ),
                              onAddToFocus: () => _addToFocus(context, task),
                              onToggleComplete: (done) async {
                                await TaskStore.instance.setCompletion(task.id, done);
                                FocusQueueStore.instance.markTaskCompletion(task.id, done);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TaskItem> _ownedTasks(List<TaskItem> tasks) {
    return tasks.where((task) => task.assignee == TaskStore.currentUser).toList();
  }

  List<QuickStatItem> _buildQuickStats(List<TaskItem> tasks) {
    final total = tasks.length;
    final done = tasks.where((task) => task.isDone).length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final dueSoon = tasks.where((task) => task.isDueSoon).length;
    final projectCount = tasks
        .where((task) => task.hasProject)
        .map((task) => task.projectId)
        .whereType<String>()
        .toSet()
        .length;

    return [
      QuickStatItem(
        label: 'Tasks',
        value: '$done/$total',
        icon: Icons.task_alt,
        iconColor: AppColors.burntOrange,
      ),
      QuickStatItem(
        label: 'Overdue',
        value: '$overdue',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.tomatoRed,
      ),
      QuickStatItem(
        label: 'Due Soon',
        value: '$dueSoon',
        icon: Icons.schedule_rounded,
        iconColor: AppColors.mustardYellow,
      ),
      QuickStatItem(
        label: 'Projects',
        value: '$projectCount',
        icon: Icons.folder_open_rounded,
        iconColor: AppColors.successGreen,
      ),
    ];
  }

  Future<void> _showQuickCreate(BuildContext context) async {
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
                  subtitle: const Text('Quick add a new task'),
                  onTap: () async {
                    Navigator.pop(context);
                    final created = await showTaskEditorDialog(context);
                    if (created == null) {
                      return;
                    }
                    await TaskStore.instance.addTask(created);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: const Text('Create Project'),
                  subtitle: const Text('Start a new project workspace'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessage(context, 'Quick project creation is coming next.');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTask(BuildContext context, TaskItem task) async {
    if (!TaskStore.instance.canEdit(task)) {
      _showMessage(context, 'Only the task owner can edit this task.');
      return;
    }

    final updated = await showTaskEditorDialog(context, existing: task);
    if (updated == null) {
      return;
    }

    await TaskStore.instance.updateTask(updated);
  }

  void _addToFocus(BuildContext context, TaskItem task) {
    FocusQueueStore.instance.enqueue(task);
    _showMessage(context, 'Added "${task.title}" to Focus queue.');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionText});

  final String title;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        if (actionText != null)
          Text(
            actionText!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.burntOrange,
                  fontWeight: FontWeight.w700,
                ),
          ),
      ],
    );
  }
}

class _CookedMeterCard extends StatelessWidget {
  const _CookedMeterCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TaskItem>>(
      valueListenable: TaskStore.instance.tasksNotifier,
      builder: (context, tasks, _) {
        final meter = _buildCookedMeter(tasks);
        final stageColor = _stageColor(meter.stage);

        return ValueListenableBuilder<MascotState>(
          valueListenable: MascotStore.instance.state,
          builder: (context, mascotState, _) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    meter.stageLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: stageColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.progressTrack,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(mascotState.imageAssetPath, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.burntOrange,
                      foregroundColor: AppColors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      );
                    },
                    child: const Text('Change mascot'),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: meter.value / 100,
                      minHeight: 14,
                      backgroundColor: AppColors.progressTrack,
                      color: stageColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${meter.value.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${mascotState.mascotLabel} is currently ${meter.stageLabel.toLowerCase()} based on your live task progress.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  _CookedMeterSnapshot _buildCookedMeter(List<TaskItem> allTasks) {
    final tasks = allTasks.where((task) => task.assignee == TaskStore.currentUser).toList();
    if (tasks.isEmpty) {
      return const _CookedMeterSnapshot(value: 25, stage: CookedStage.cozy);
    }

    final total = tasks.length;
    final done = tasks.where((task) => task.isDone).length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final dueSoon = tasks.where((task) => task.isDueSoon).length;
    final projects = tasks.where((task) => task.hasProject).length;

    final completionScore = (done / total) * 100;
    final raw = completionScore + (projects * 1.5) - (overdue * 10) - (dueSoon * 4);
    final value = raw.clamp(0, 100).toDouble();

    return _CookedMeterSnapshot(value: value, stage: _stageForValue(value));
  }

  CookedStage _stageForValue(double value) {
    if (value < 25) {
      return CookedStage.cozy;
    }
    if (value < 55) {
      return CookedStage.cooked;
    }
    if (value < 80) {
      return CookedStage.crispy;
    }
    return CookedStage.overcooked;
  }

  Color _stageColor(CookedStage stage) {
    return switch (stage) {
      CookedStage.cozy => AppColors.successGreen,
      CookedStage.cooked => AppColors.burntOrange,
      CookedStage.crispy => AppColors.mustardYellow,
      CookedStage.overcooked => AppColors.tomatoRed,
    };
  }
}

class _CookedMeterSnapshot {
  const _CookedMeterSnapshot({required this.value, required this.stage});

  final double value;
  final CookedStage stage;

  String get stageLabel {
    return switch (stage) {
      CookedStage.cozy => 'Cozy',
      CookedStage.cooked => 'Cooked',
      CookedStage.crispy => 'Crispy',
      CookedStage.overcooked => 'Overcooked',
    };
  }
}
