import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../prayers/domain/today_prayer.dart';
import '../../prayers/presentation/prayer_library_tile.dart';
import '../../prayers/providers/prayer_providers.dart';

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

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
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
