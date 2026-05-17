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
                      return ValueListenableBuilder<MascotState>(
                        valueListenable: MascotStore.instance.state,
                        builder: (context, mascotState, _) {
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
    return tasks
        .where((task) => TaskStore.instance.isCurrentUserLabel(task.assignee))
        .toList();
  }

  List<QuickStatItem> _buildQuickStats(List<TaskItem> tasks) {
    final total = tasks.length;
    final done = tasks.where((task) => task.isDone).length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final dueSoon = tasks.where((task) => task.isDueSoon).length;
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

class _CookedMeterCard extends StatefulWidget {
  const _CookedMeterCard();

  @override
  State<_CookedMeterCard> createState() => _CookedMeterCardState();
}

class _CookedMeterCardState extends State<_CookedMeterCard> {
  double? _lastSyncedMeter;

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
            if ((_lastSyncedMeter ?? -1) != meter.value) {
              _lastSyncedMeter = meter.value;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                if ((MascotStore.instance.state.value.cookedMeter - meter.value).abs() > 0.1) {
                  MascotStore.instance.setCookedMeter(meter.value);
                }
              });
            }

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
                    alignment: Alignment.center,
                    child: Image.asset(
                      mascotState.imageAssetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.burntOrange,
                      foregroundColor: AppColors.white,
                    ),
                    onPressed: () => _showOwnedMascotsPicker(context),
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
    final tasks = allTasks
        .where((task) => TaskStore.instance.isCurrentUserLabel(task.assignee))
        .toList();
    if (tasks.isEmpty) {
      return const _CookedMeterSnapshot(value: 25, stage: CookedStage.cozy);
    }

    final total = tasks.length;
    final done = tasks.where((task) => task.state == TaskState.done || task.completed).length;
    final inProgress = tasks.where((task) => task.state == TaskState.inProgress).length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final dueSoon = tasks.where((task) => task.isDueSoon).length;

    // Inverse logic: meter should go DOWN when tasks are completed
    // More incomplete tasks = higher meter (more urgent)
    final incompleteScore = ((total - done) / total) * 75;
    final urgencyBonus = (inProgress / total) * 12;
    final overduePenalty = overdue * 18;
    final dueSoonPenalty = dueSoon * 6;
    final raw = incompleteScore + urgencyBonus + overduePenalty + dueSoonPenalty + 20;
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

  Future<void> _showOwnedMascotsPicker(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<MascotState>(
          valueListenable: MascotStore.instance.state,
          builder: (context, mascotState, _) {
            final owned = mascotState.ownedMascots.toList();
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'My Mascots',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap a mascot to equip it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 14),
                    if (owned.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'You don\'t own any mascots yet. Visit the shop to unlock more!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: owned.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) {
                          final kind = owned[index];
                          final isSelected = kind == mascotState.kind;
                          return InkWell(
                            onTap: () async {
                              await MascotStore.instance.setKind(kind);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.burntOrange
                                      : AppColors.cardStroke,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      mascotKindAsset(kind),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.pets_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    mascotKindLabel(kind),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.burntOrange
                                              : AppColors.textPrimary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShopScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Browse shop'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
