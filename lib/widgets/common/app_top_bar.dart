import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mascot_store.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.coins,
    this.showShopAction = true,
    this.onShopTap,
  });

  final String title;
  final int? coins;
  final bool showShopAction;
  final VoidCallback? onShopTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
            ),
          ),
          ValueListenableBuilder<MascotState>(
            valueListenable: MascotStore.instance.state,
            builder: (context, mascotState, _) {
              final value = coins ?? mascotState.coinBalance;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: AppColors.mustardYellow),
                    const SizedBox(width: 6),
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.mustardYellow,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (showShopAction) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open Shop',
              onPressed: onShopTap,
              icon: const Icon(Icons.storefront_outlined, color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
