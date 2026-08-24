import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/quick_stat_item.dart';

class QuickStatCard extends StatelessWidget {
  const QuickStatCard({super.key, required this.item});

  final QuickStatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: item.iconColor.withValues(alpha: 0.14),
            child: Icon(item.icon, color: item.iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
