import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mascot_store.dart';
import '../../widgets/common/app_top_bar.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Future<void> _handleMascotAction({
    required MascotState state,
    required MascotKind kind,
    required int price,
  }) async {
    final isOwned = state.ownedMascots.contains(kind);
    if (isOwned) {
      await MascotStore.instance.setKind(kind);
      if (!mounted) return;
      _showMessage('Mascot equipped.');
      return;
    }

    if (state.coinBalance < price) {
      _showMessage('Not enough coins to buy this mascot.');
      return;
    }

    try {
      await MascotStore.instance.purchaseMascot(kind, price);
    } on StateError catch (e) {
      _showMessage(e.message);
      return;
    }
    if (!mounted) return;
    _showMessage('Purchase complete. Mascot unlocked and equipped.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MascotState>(
      valueListenable: MascotStore.instance.state,
      builder: (context, state, _) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AppTopBar(
                  title: 'Shop',
                  showShopAction: false,
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 6),
                    Text(
                      'Mascots',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earn 50 coins when you complete a task.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final all = <Map<String, dynamic>>[
                          {
                            'kind': MascotKind.gigaToast,
                            'title': 'Giga Toast',
                            'price': 300,
                            'asset': 'assets/mascots/giga_toast/cozy.png',
                          },
                          {
                            'kind': MascotKind.potato,
                            'title': 'Potato',
                            'price': 0,
                            'asset': 'assets/mascots/potato/cozy.png',
                          },
                          {
                            'kind': MascotKind.student,
                            'title': 'Student',
                            'price': 220,
                            'asset': 'assets/mascots/student/cozy.png',
                          },
                        ];

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxis = constraints.maxWidth > 700
                                ? 3
                                : 2;
                            return GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: all.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxis,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: constraints.maxWidth > 700
                                        ? 0.82
                                        : 0.68,
                                  ),
                              itemBuilder: (context, idx) {
                                final item = all[idx];
                                final kind = item['kind'] as MascotKind;
                                final title = item['title'] as String;
                                final price = item['price'] as int;
                                final asset = item['asset'] as String;

                                return _MascotCard(
                                  title: title,
                                  price: price,
                                  asset: asset,
                                  isOwned: state.ownedMascots.contains(kind),
                                  isEquipped: state.kind == kind,
                                  canAfford: state.coinBalance >= price,
                                  onBuy: () => _handleMascotAction(
                                    state: state,
                                    kind: kind,
                                    price: price,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MascotCard extends StatelessWidget {
  const _MascotCard({
    required this.title,
    required this.price,
    required this.asset,
    required this.isOwned,
    required this.isEquipped,
    required this.canAfford,
    required this.onBuy,
  });

  final String title;
  final int price;
  final String asset;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.progressTrack,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.pets_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (isOwned)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEquipped ? 'Equipped' : 'Owned',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isEquipped
                      ? AppColors.successGreen
                      : AppColors.statusInProgress,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.monetization_on,
                size: 14,
                color: AppColors.mustardYellow,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOwned
                      ? 'Yours'
                      : price == 0
                      ? 'Free'
                      : '$price coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.burntOrange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isEquipped ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                foregroundColor: AppColors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                isEquipped
                    ? 'On'
                    : isOwned
                    ? 'Equip'
                    : canAfford || price == 0
                    ? 'Buy'
                    : 'Locked',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
