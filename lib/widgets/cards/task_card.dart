import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/task_item.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isOverdue ? AppColors.tomatoRed.withValues(alpha: 0.35) : AppColors.cardStroke,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isDone,
            onChanged: (value) => onToggleComplete?.call(value ?? false),
            activeColor: AppColors.burntOrange,
            visualDensity: VisualDensity.compact,
          ),
          Container(
            width: 4,
            height: compact ? 44 : 62,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(
              color: task.priorityColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: task.priorityColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    task.subject,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (task.hasProject && showProjectLink) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 14,
                        color: AppColors.statusInProgress.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          task.projectTitle ?? 'Project linked',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ownerLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: ownerLabel == 'Unclaimed'
                                ? AppColors.mustardYellow.withValues(alpha: 0.2)
                                : AppColors.statusInProgress.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            ownerLabel!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ownerLabel == 'Unclaimed'
                                      ? AppColors.textPrimary
                                      : AppColors.statusInProgress,
                                ),
                          ),
                        ),
                      if (onClaim != null) const SizedBox(width: 8),
                      const Spacer(),
                      if (onClaim != null)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.2),
                            disabledForegroundColor: AppColors.textSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          ),
                          onPressed: canClaim ? onClaim : null,
                          icon: const Icon(Icons.pan_tool_alt_rounded, size: 16),
                          label: Text(canClaim ? 'Claim This Task' : 'Claim Disabled'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: task.isOverdue ? AppColors.tomatoRed : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.deadlineLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: task.isOverdue ? AppColors.tomatoRed : AppColors.textSecondary,
                            fontWeight: task.isOverdue || task.isDueSoon ? FontWeight.w800 : FontWeight.w600,
                          ),
                    ),
                    if (task.isOverdue) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Overdue',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.tomatoRed,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ] else if (task.isDueSoon) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Due soon',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.burntOrange,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: task.stateColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.stateLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (onEdit != null)
                IconButton(
                  tooltip: canEdit ? 'Edit task' : 'Only task owner can edit',
                  onPressed: canEdit ? onEdit : onEditLocked,
                  icon: Icon(
                    canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded,
                    color: canEdit ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              if (onAddToFocus != null)
                IconButton(
                  tooltip: 'Send to Focus',
                  onPressed: onAddToFocus,
                  icon: const Icon(Icons.playlist_add_rounded, color: AppColors.burntOrange),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete task',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.tomatoRed),
                ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
