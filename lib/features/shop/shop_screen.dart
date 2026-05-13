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
  int _coins = 420;
  final Set<MascotKind> _ownedMascots = <MascotKind>{MascotKind.potato};

  Future<void> _handleMascotAction({
    required MascotState state,
    required MascotKind kind,
    required int price,
  }) async {
    final isOwned = _ownedMascots.contains(kind);
    if (isOwned) {
      await MascotStore.instance.setKind(kind);
      if (!mounted) {
        return;
      }
      _showMessage('Mascot equipped.');
      return;
    }

    if (_coins < price) {
      _showMessage('Not enough coins to buy this mascot.');
      return;
    }

    setState(() {
      _coins -= price;
      _ownedMascots.add(kind);
    });
    await MascotStore.instance.setKind(kind);
    if (!mounted) {
      return;
    }
    _showMessage('Purchase complete. Mascot unlocked and equipped.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MascotState>(
      valueListenable: MascotStore.instance.state,
      builder: (context, state, _) {
        _ownedMascots.add(state.kind);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                      ),
                      Expanded(
                        child: AppTopBar(
                          title: 'Campus Shop',
                          showShopAction: false,
                          coins: _coins,
                        ),
                      ),
                    ],
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Build a responsive grid of compact mascot cards (hide owned)
                    Builder(builder: (context) {
                      // Ensure we know the currently owned mascot
                      _ownedMascots.add(state.kind);

                      final all = <Map<String, dynamic>>[
                        {
                          'kind': MascotKind.gigaToast,
                          'title': 'Giga Toast',
                          'price': 300,
                          'asset': 'assets/mascots/giga_toast/cozy.png'
                        },
                        {
                          'kind': MascotKind.potato,
                          'title': 'Potato',
                          'price': 0,
                          'asset': 'assets/mascots/potato/cozy.png'
                        },
                        {
                          'kind': MascotKind.student,
                          'title': 'Student',
                          'price': 220,
                          'asset': 'assets/mascots/student/cozy.png'
                        },
                      ];

                      final available = all.where((m) => !_ownedMascots.contains(m['kind'] as MascotKind)).toList();

                      if (available.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No mascots available to buy',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxis = constraints.maxWidth > 700 ? 3 : 2;
                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: available.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxis,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.68,
                            ),
                            itemBuilder: (context, idx) {
                              final item = available[idx];
                              final kind = item['kind'] as MascotKind;
                              final title = item['title'] as String;
                              final price = item['price'] as int;
                              final asset = item['asset'] as String;

                              return _MascotCard(
                                title: title,
                                price: price,
                                asset: asset,
                                onBuy: () => _handleMascotAction(state: state, kind: kind, price: price),
                              );
                            },
                          );
                        },
                      );
                    }),
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

// Removed banner per redesign: shop now shows only mascot cards.

// _MascotChoiceTile removed — replaced by compact grid cards above.

// Utilities removed from shop — utility tiles no longer used.

class _MascotCard extends StatelessWidget {
  const _MascotCard({
    required this.title,
    required this.price,
    required this.asset,
    required this.onBuy,
  });

  final String title;
  final int price;
  final String asset;
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
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.progressTrack,
                  alignment: Alignment.center,
                  child: const Icon(Icons.pets_rounded, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, size: 14, color: AppColors.mustardYellow),
                    const SizedBox(width: 6),
                    Text(
                      price == 0 ? 'Free' : '$price',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mustardYellow,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onBuy,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burntOrange,
                  foregroundColor: AppColors.white,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Buy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
