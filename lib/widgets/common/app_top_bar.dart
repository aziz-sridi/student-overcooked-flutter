import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mascot_store.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.leading,
    this.coins,
    this.showShopAction = true,
    this.onShopTap,
  });

  final String title;
  final Widget? leading;
  final int? coins;
  final bool showShopAction;
  final VoidCallback? onShopTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(width: 44, height: 44, child: leading),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 23,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<MascotState>(
            valueListenable: MascotStore.instance.state,
            builder: (context, mascotState, _) {
              final value = coins ?? mascotState.coinBalance;
              return SizedBox(
                width: 78,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.mustardYellow.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.mustardYellow.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 20,
                          color: AppColors.burntOrange,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$value',
                              maxLines: 1,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            height: 40,
            child: showShopAction
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.burntOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'Open shop',
                      onPressed: onShopTap,
                      icon: const Icon(
                        Icons.storefront_outlined,
                        size: 21,
                        color: AppColors.burntOrange,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
