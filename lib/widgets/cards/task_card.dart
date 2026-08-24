import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/task_item.dart';

enum _TaskMenuAction { edit, focus, delete, more }

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.compact = false,
    this.onMore,
    this.onToggleComplete,
    this.onAddToFocus,
    this.onEdit,
    this.canEdit = true,
    this.onEditLocked,
    this.showProjectLink = true,
    this.ownerLabel,
    this.onClaim,
    this.canClaim = true,
    this.onDelete,
  });

  final TaskItem task;
  final bool compact;
  final VoidCallback? onMore;
  final ValueChanged<bool>? onToggleComplete;
  final VoidCallback? onAddToFocus;
  final VoidCallback? onEdit;
  final bool canEdit;
  final VoidCallback? onEditLocked;
  final bool showProjectLink;
  final String? ownerLabel;
  final VoidCallback? onClaim;
  final bool canClaim;
  final VoidCallback? onDelete;

  bool get _hasMenuActions =>
      onEdit != null ||
      onAddToFocus != null ||
      onDelete != null ||
      onMore != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isOverdue
              ? AppColors.tomatoRed.withValues(alpha: 0.38)
              : Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: task.isDone
                ? 'Mark ${task.title} as not complete'
                : 'Mark ${task.title} as complete',
            child: Checkbox(
              value: task.isDone,
              onChanged: onToggleComplete == null
                  ? null
                  : (value) => _requestCompletion(context, value ?? false),
              activeColor: AppColors.burntOrange,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                    ),
                    if (_hasMenuActions)
                      PopupMenuButton<_TaskMenuAction>(
                        tooltip: 'Task actions',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: _handleMenuAction,
                        itemBuilder: (context) => [
                          if (onEdit != null)
                            PopupMenuItem(
                              value: _TaskMenuAction.edit,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  canEdit
                                      ? Icons.edit_outlined
                                      : Icons.lock_outline_rounded,
                                ),
                                title: Text(
                                  canEdit ? 'Edit task' : 'Edit locked',
                                ),
                              ),
                            ),
                          if (onAddToFocus != null)
                            const PopupMenuItem(
                              value: _TaskMenuAction.focus,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.playlist_add_rounded),
                                title: Text('Send to Focus'),
                              ),
                            ),
                          if (onMore != null)
                            const PopupMenuItem(
                              value: _TaskMenuAction.more,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.more_horiz_rounded),
                                title: Text('More options'),
                              ),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: _TaskMenuAction.delete,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.tomatoRed,
                                ),
                                title: Text(
                                  'Delete task',
                                  style: TextStyle(color: AppColors.tomatoRed),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(
                      label: task.subject,
                      background: task.priorityColor.withValues(alpha: 0.14),
                      foreground: Theme.of(context).colorScheme.onSurface,
                    ),
                    _Tag(
                      label: '${_priorityLabel(task.priority)} priority',
                      background: task.priorityColor.withValues(alpha: 0.12),
                      foreground: task.priority == TaskPriority.medium
                          ? Theme.of(context).colorScheme.onSurface
                          : task.priorityColor,
                    ),
                  ],
                ),
                if (task.hasProject && showProjectLink) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_open_rounded,
                        size: 14,
                        color: AppColors.statusInProgress,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          task.projectTitle ?? 'Project linked',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.statusInProgress,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (ownerLabel != null || onClaim != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ownerLabel != null)
                        _Tag(
                          label: ownerLabel!,
                          background: ownerLabel == 'Unclaimed'
                              ? AppColors.mustardYellow.withValues(alpha: 0.2)
                              : AppColors.statusInProgress.withValues(
                                  alpha: 0.15,
                                ),
                          foreground: ownerLabel == 'Unclaimed'
                              ? Theme.of(context).colorScheme.onSurface
                              : AppColors.statusInProgress,
                        ),
                      if (onClaim != null)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                          ),
                          onPressed: canClaim ? onClaim : null,
                          icon: const Icon(
                            Icons.pan_tool_alt_rounded,
                            size: 16,
                          ),
                          label: Text(
                            canClaim ? 'Claim task' : 'Claim disabled',
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _IconLabel(
                      icon: Icons.calendar_today_rounded,
                      label: task.deadlineLabel,
                      color: task.isOverdue
                          ? AppColors.tomatoRed
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    if (task.isOverdue)
                      const _Tag(
                        label: 'Overdue',
                        background: Color(0xFFFFE6E3),
                        foreground: AppColors.tomatoRed,
                      )
                    else if (task.isDueSoon)
                      _Tag(
                        label: 'Due soon',
                        background: AppColors.burntOrange.withValues(
                          alpha: 0.12,
                        ),
                        foreground: AppColors.burntOrange,
                      ),
                    _Tag(
                      label: task.stateLabel,
                      background: task.stateColor.withValues(alpha: 0.14),
                      foreground: task.stateColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCompletion(BuildContext context, bool done) async {
    if (!done) {
      onToggleComplete?.call(false);
      return;
    }

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
    if (confirmed == true) onToggleComplete?.call(true);
  }

  void _handleMenuAction(_TaskMenuAction action) {
    switch (action) {
      case _TaskMenuAction.edit:
        canEdit ? onEdit?.call() : onEditLocked?.call();
      case _TaskMenuAction.focus:
        onAddToFocus?.call();
      case _TaskMenuAction.delete:
        onDelete?.call();
      case _TaskMenuAction.more:
        onMore?.call();
    }
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
