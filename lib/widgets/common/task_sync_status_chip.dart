import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/task_store.dart';

class TaskSyncStatusChip extends StatelessWidget {
  const TaskSyncStatusChip({
    super.key,
    required this.state,
    this.onRetry,
  });

  final TaskSyncState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(state.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: config.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.foreground),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: config.foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if ((state.errorCode ?? '').isNotEmpty)
                Text(
                  'code: ${state.errorCode}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: config.foreground.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
          if (state.status == TaskSyncStatus.error && onRetry != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: config.foreground,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusConfig _configFor(TaskSyncStatus status) {
    switch (status) {
      case TaskSyncStatus.loading:
        return const _StatusConfig(
          label: 'Loading tasks',
          icon: Icons.hourglass_bottom_rounded,
          foreground: AppColors.textSecondary,
          background: Color(0xFFF7F7F7),
          border: AppColors.divider,
        );
      case TaskSyncStatus.syncing:
        return const _StatusConfig(
          label: 'Syncing',
          icon: Icons.sync_rounded,
          foreground: AppColors.statusInProgress,
          background: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
        );
      case TaskSyncStatus.synced:
        return const _StatusConfig(
          label: 'Synced',
          icon: Icons.cloud_done_rounded,
          foreground: AppColors.successGreen,
          background: Color(0xFFEFFAF0),
          border: Color(0xFFC8E6C9),
        );
      case TaskSyncStatus.offline:
        return const _StatusConfig(
          label: 'Offline cache',
          icon: Icons.cloud_off_rounded,
          foreground: AppColors.textSecondary,
          background: Color(0xFFFFF8E1),
          border: Color(0xFFFFECB3),
        );
      case TaskSyncStatus.error:
        return const _StatusConfig(
          label: 'Sync issue',
          icon: Icons.error_outline_rounded,
          foreground: AppColors.tomatoRed,
          background: Color(0xFFFFF1F0),
          border: Color(0xFFFFCDD2),
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}
