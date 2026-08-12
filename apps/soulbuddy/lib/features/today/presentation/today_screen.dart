import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/presentation/living_vine.dart';
import '../../prayers/domain/today_prayer.dart';
import '../../prayers/presentation/prayer_library_tile.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../remember/presentation/daily_remembrance_card.dart';
import '../../remember/providers/daily_memory_providers.dart';
import 'today_start_guide.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _updatingAction = false;

  @override
  Widget build(BuildContext context) {
    final todayPrayer = ref.watch(todayPrayerProvider);
    final dailyMemory = ref.watch(dailyMemoryProvider);
    final showStartGuide =
        todayPrayer is AsyncData<TodayPrayer?> &&
        dailyMemory is AsyncData &&
        todayPrayer.value == null &&
        dailyMemory.value == null;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Today',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Pray. Act. Remember.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (!showStartGuide &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.5) ...[
                    const SizedBox(width: AppSpacing.md),
                    const SizedBox(
                      width: 144,
                      child: LivingVine(
                        key: Key('today-living-vine'),
                        variant: LivingVineVariant.blossom,
                        animate: true,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (showStartGuide)
                TodayStartGuide(
                  onChoosePrayer: () => context.go('/prayers'),
                  onRecordMemory: () => context.go('/record'),
                )
              else
                todayPrayer.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => _TodayUnavailable(
                    onRetry: () => retryTodayPrayerProvider(ref),
                  ),
                  data: (today) => today == null
                      ? const _NoPrayerSelected()
                      : _SelectedPrayer(
                          today: today,
                          updatingAction: _updatingAction,
                          onActionChanged: (value) =>
                              _completeAction(today, value),
                        ),
                ),
              if (!showStartGuide) const SizedBox(height: AppSpacing.lg),
              if (!showStartGuide)
                dailyMemory.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => retryDailyMemoryProvider(ref),
                      child: const Text('Open remembrance again'),
                    ),
                  ),
                  data: (daily) => daily == null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            key: const Key('record-something-to-remember'),
                            onPressed: () => context.go('/record'),
                            child: const Text('Record something to remember'),
                          ),
                        )
                      : DailyRemembranceCard(dailyMemory: daily),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeAction(TodayPrayer displayedToday, bool value) async {
    setState(() => _updatingAction = true);
    try {
      final repositoryFuture = ref.read(prayerRepositoryProvider.future);
      final repository = await repositoryFuture;
      await repository.completeTodayAction(
        displayedToday.localDate,
        expectedPrayer: displayedToday.prayer.reference,
        value: value,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the action. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAction = false);
    }
  }
}

class _NoPrayerSelected extends StatelessWidget {
  const _NoPrayerSelected();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        key: const Key('choose-prayer'),
        onPressed: () => context.go('/prayers'),
        child: const Text('Choose a prayer for today'),
      ),
    );
  }
}

class _SelectedPrayer extends StatelessWidget {
  const _SelectedPrayer({
    required this.today,
    required this.updatingAction,
    required this.onActionChanged,
  });

  final TodayPrayer today;
  final bool updatingAction;
  final ValueChanged<bool> onActionChanged;

  @override
  Widget build(BuildContext context) {
    final prayer = today.prayer;
    final action = prayer.action?.trim();
    final showsAction =
        today.includeAction && action != null && action.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${prayerPurposeLabel(prayer.purpose)} · '
                  '${prayerGroundingLabel(prayer.grounding)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  prayer.body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
        ),
        if (showsAction) ...[
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.componentRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practical action',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(action),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    key: const Key('today-action-done'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Done'),
                    value: today.actionCompleted,
                    onChanged: updatingAction
                        ? null
                        : (value) {
                            if (value != null) onActionChanged(value);
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextButton(
          key: const Key('choose-different-prayer'),
          onPressed: updatingAction ? null : () => context.go('/prayers'),
          child: const Text('Choose a different prayer'),
        ),
      ],
    );
  }
}

class _TodayUnavailable extends StatelessWidget {
  const _TodayUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s prayer could not be opened just now.'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
