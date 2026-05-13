import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/focus_queue_store.dart';
import '../../models/task_item.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool pomodoro = true;
  bool isPlaying = false;
  String selectedAmbient = 'White Noise';
  double volume = 0.6;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'Focus Mode',
              onShopTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: 0.32,
                              strokeWidth: 10,
                              backgroundColor: AppColors.divider,
                              color: AppColors.burntOrange,
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '25:00',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Focus',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Start'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              child: const Text('Skip Break'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              selected: pomodoro,
                              label: const Center(child: Text('Pomodoro')),
                              onSelected: (_) => setState(() => pomodoro = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              selected: !pomodoro,
                              label: const Center(child: Text('Custom')),
                              onSelected: (_) => setState(() => pomodoro = false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Ambient Player',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                         
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF3E8), Color(0xFFFFE2C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardStroke),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.burntOrange.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: AppColors.burntOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedAmbient,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Focus Mix',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final ambient in const ['White Noise', 'Rain', 'Cafe', 'Forest'])
                            ChoiceChip(
                              label: Text(ambient),
                              selected: selectedAmbient == ambient,
                              onSelected: (_) => setState(() => selectedAmbient = ambient),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: () => setState(() => isPlaying = !isPlaying),
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: AppColors.burntOrange,
                              foregroundColor: AppColors.white,
                            ),
                            child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded, size: 18),
                          Expanded(
                            child: Slider(
                              value: volume,
                              onChanged: (value) => setState(() => volume = value),
                              activeColor: AppColors.burntOrange,
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FocusQueueCard(
                  onToggleComplete: (id, done) {
                    FocusQueueStore.instance.markTaskCompletion(id, done);
                  },
                  onRemove: (id) {
                    FocusQueueStore.instance.remove(id);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusQueueCard extends StatelessWidget {
  const _FocusQueueCard({
    required this.onToggleComplete,
    required this.onRemove,
  });

  final void Function(String id, bool done) onToggleComplete;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ValueListenableBuilder<List<TaskItem>>(
        valueListenable: FocusQueueStore.instance.queue,
        builder: (context, queue, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Queue',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep working here without leaving Focus mode.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              if (queue.isEmpty)
                Text(
                  'No queued tasks yet. Add tasks from the Tasks page.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                )
              else
                for (final task in queue)
                  Dismissible(
                    key: ValueKey('focus-${task.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => onRemove(task.id),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: AppColors.tomatoRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.white),
                    ),
                    child: TaskCard(
                      task: task,
                      onToggleComplete: (done) => onToggleComplete(task.id, done),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
