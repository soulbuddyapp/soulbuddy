import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../../core/presentation/covenant_slabs.dart';
import '../../altar/presentation/altar_today_card.dart';
import '../../goals/application/goal_today_composer.dart';
import '../../goals/application/goal_today_resource_adapter.dart';
import '../../goals/presentation/goal_today_sections.dart';
import '../../goals/presentation/today_prayer_goal_migration_card.dart';
import '../../goals/providers/goal_providers.dart';
import '../../goals/providers/goal_today_providers.dart';
import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/today_prayer.dart';
import '../../prayers/presentation/prayer_library_tile.dart';
import '../../prayers/presentation/prayer_reminder_card.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../remember/presentation/daily_remembrance_card.dart';
import '../../remember/providers/daily_memory_providers.dart';
import '../domain/daily_practice_state.dart';
import '../providers/daily_practice_providers.dart';
import 'today_start_guide.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _updatingAction = false;
  var _recordingPrayer = false;

  @override
  Widget build(BuildContext context) {
    final todayPrayer = ref.watch(todayPrayerProvider);
    final dailyMemory = ref.watch(dailyMemoryProvider);
    final dailyPractices = ref.watch(dailyPracticeStateProvider);
    final goalToday = ref.watch(goalTodaySnapshotProvider);
    final goalSnapshot = switch (goalToday) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final showStartGuide =
        todayPrayer is AsyncData<TodayPrayer?> &&
        dailyMemory is AsyncData &&
        todayPrayer.value == null &&
        dailyMemory.value == null &&
        (goalSnapshot == null || goalSnapshot.activeGoalCount == 0);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Today',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'What needs your attention now?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              dailyPractices.when(
                loading: () => const SizedBox(
                  height: 132,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) =>
                    _PracticeUnavailable(onRetry: _retryDailyPractices),
                data: (state) => CovenantSlabs(
                  key: const Key('today-covenant-slabs'),
                  state: state,
                  animate: true,
                  height: showStartGuide ? 86 : 104,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (goalSnapshot != null) ...[
                if (goalSnapshot.sections.isNotEmpty)
                  GoalTodaySections(
                    snapshot: goalSnapshot,
                    onCompleteAction: (item) =>
                        _completeGoalAction(goalSnapshot, item),
                    onOpenResource: _openGoalResource,
                    onCompleteResource: _completeGoalResource,
                  )
                else if (goalSnapshot.activeGoalCount > 0)
                  const _NoGoalAttention(),
                if (goalSnapshot.resources.dueRemindersOutsideActiveGoals
                    .isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrayerReminderCard(
                    key: ValueKey(
                      goalSnapshot
                          .resources
                          .dueRemindersOutsideActiveGoals
                          .first
                          .occurrenceKey,
                    ),
                    occurrence: goalSnapshot
                        .resources
                        .dueRemindersOutsideActiveGoals
                        .first,
                    dueCount: goalSnapshot
                        .resources
                        .dueRemindersOutsideActiveGoals
                        .length,
                    reduceMotion:
                        MediaQuery.maybeOf(context)?.disableAnimations ?? false,
                  ),
                ],
                if (goalSnapshot.sections.isNotEmpty ||
                    goalSnapshot.activeGoalCount > 0 ||
                    goalSnapshot.resources.dueRemindersOutsideActiveGoals
                        .isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
              ] else if (goalToday is AsyncError) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _retryGoalToday,
                    child: const Text('Open Goals for today again'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const AltarTodaySection(),
              SizedBox(height: showStartGuide ? AppSpacing.sm : AppSpacing.md),
              if (showStartGuide)
                TodayStartGuide(
                  onChoosePrayer: () => context.go('/prayers'),
                  onRecordMemory: () => context.go('/record'),
                )
              else
                _legacyTodayContent(
                  todayPrayer: todayPrayer,
                  dailyPractices: dailyPractices,
                  goalSnapshot: goalSnapshot,
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

  Widget _legacyTodayContent({
    required AsyncValue<TodayPrayer?> todayPrayer,
    required AsyncValue<DailyPracticeState> dailyPractices,
    required GoalTodaySnapshot? goalSnapshot,
  }) {
    if (goalSnapshot != null) {
      final today = goalSnapshot.resources.legacyTodayOutsideActiveGoals;
      if (today == null) return const SizedBox.shrink();
      return _selectedLegacyPrayer(today, dailyPractices);
    }

    return todayPrayer.when(
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
          : _selectedLegacyPrayer(today, dailyPractices),
    );
  }

  Widget _selectedLegacyPrayer(
    TodayPrayer today,
    AsyncValue<DailyPracticeState> dailyPractices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TodayPrayerGoalMigrationCard(today: today),
        _SelectedPrayer(
          today: today,
          prayerCompletionKnown: dailyPractices is AsyncData<DailyPracticeState>,
          prayed:
              dailyPractices.value?.completed.contains(DailyPractice.pray) ??
              false,
          recordingPrayer: _recordingPrayer,
          updatingAction: _updatingAction,
          onPrayerCompleted: () => _recordPrayer(today),
          onActionChanged: (value) => _completeAction(today, value),
        ),
      ],
    );
  }

  Future<void> _completeGoalAction(
    GoalTodaySnapshot snapshot,
    GoalTodayActionItem item,
  ) async {
    try {
      final repository = await ref.read(goalRepositoryProvider.future);
      final event = await repository.completeAction(
        item.occurrence.action.id,
        localDate: snapshot.localDate,
      );
      if (!mounted || event == null) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: const Text('Done'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(
              _undoGoalAction(
                undo: () async {
                  await repository.retractAction(
                    item.occurrence.action.id,
                    localDate: snapshot.localDate,
                  );
                },
                messenger: messenger,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this Goal action. Try again.'),
        ),
      );
    }
  }

  Future<void> _undoGoalAction({
    required Future<void> Function() undo,
    required ScaffoldMessengerState messenger,
  }) async {
    try {
      await undo();
    } catch (_) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not undo this action just now.')),
      );
    }
  }

  Future<void> _openGoalResource(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle? handle,
  ) async {
    if (!mounted) return;
    switch (handle) {
      case GoalTodayReminderHandle(:final occurrence):
        context.go('/prayers/saved/${occurrence.reminder.personalPrayerId}');
      case GoalTodayLinkedPrayerHandle(:final prayer):
        _openPrayerReference(prayer);
      case GoalTodayLegacyPrayerHandle(:final today):
        _openPrayerReference(today.prayer.reference);
      case GoalTodayScriptureHandle(:final link):
        final book = Uri.encodeComponent(link.book!);
        context.go('/remember/scripture/$book/${link.chapter}');
      case null:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This resource could not be opened.')),
        );
    }
  }

  void _openPrayerReference(PrayerReference prayer) {
    final route = switch (prayer.source) {
      PrayerSource.personal => '/prayers/saved/${prayer.id}',
      PrayerSource.library => '/prayers/${prayer.id}',
    };
    context.go(route);
  }

  Future<void> _completeGoalResource(
    GoalTodayResourceItem item,
    GoalTodayResourceHandle handle,
  ) async {
    try {
      switch (handle) {
        case GoalTodayReminderHandle(:final occurrence):
          final session = await ref.read(prayerReminderActionProvider)(
            occurrence,
            PrayerReminderAction.prayed,
          );
          if (session != null && mounted) {
            _showPrayerRecorded(session.id);
          }
        case GoalTodayLegacyPrayerHandle(:final today):
          final sessionId = await _recordPrayerSession(today);
          if (mounted) _showPrayerRecorded(sessionId);
        case GoalTodayLinkedPrayerHandle() || GoalTodayScriptureHandle():
          throw StateError('Resource completion is not supported');
      }
    } on _DisplayedDayChanged {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new day has begun. Open today\'s prayer again.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record the prayer. Try again.'),
        ),
      );
    }
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

  Future<void> _recordPrayer(TodayPrayer displayedToday) async {
    setState(() => _recordingPrayer = true);
    try {
      final sessionId = await _recordPrayerSession(displayedToday);
      if (mounted) _showPrayerRecorded(sessionId);
    } on _DisplayedDayChanged {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new day has begun. Open today\'s prayer again.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not record the prayer. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingPrayer = false);
    }
  }

  Future<String> _recordPrayerSession(TodayPrayer displayedToday) async {
    final displayedDate = DateUtils.dateOnly(displayedToday.localDate);
    final currentDate = DateUtils.dateOnly(
      ref.read(prayerPracticeClockProvider)().toLocal(),
    );
    if (displayedDate != currentDate) {
      ref.invalidate(todayPrayerDateProvider);
      throw const _DisplayedDayChanged();
    }

    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final timezone = await ref.read(prayerDeviceTimezoneProvider)();
    final session = await repository.recordSession(
      prayer: displayedToday.prayer.reference,
      revisionId: displayedToday.prayerRevisionId,
      timezone: timezone,
    );
    return session.id;
  }

  void _showPrayerRecorded(String sessionId) {
    final messenger = ScaffoldMessenger.of(context);
    final retract = ref.read(prayerSessionRetractorProvider);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: const Text('Prayer time recorded'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            _undoPrayerSession(
              messenger: messenger,
              retract: retract,
              sessionId: sessionId,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _undoPrayerSession({
    required ScaffoldMessengerState messenger,
    required Future<void> Function(String) retract,
    required String sessionId,
  }) async {
    try {
      await retract(sessionId);
    } catch (_) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not undo this prayer record just now.'),
        ),
      );
    }
  }

  void _retryGoalToday() {
    if (ref.read(appDatabaseProvider).hasError) {
      ref.invalidate(appDatabaseProvider);
    }
    if (ref.read(localIdentityProvider).hasError) {
      ref.invalidate(localIdentityProvider);
    }
    ref.invalidate(goalRepositoryProvider);
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(activeGoalTodayLinksProvider);
    ref.invalidate(goalTodaySnapshotProvider);
  }

  void _retryDailyPractices() {
    if (ref.read(appDatabaseProvider).hasError) {
      ref.invalidate(appDatabaseProvider);
    }
    if (ref.read(localIdentityProvider).hasError) {
      ref.invalidate(localIdentityProvider);
    }
    ref.invalidate(prayerPracticeRepositoryProvider);
    ref.invalidate(dailyPracticeStateProvider);
  }
}

class _DisplayedDayChanged implements Exception {
  const _DisplayedDayChanged();
}

class _NoGoalAttention extends StatelessWidget {
  const _NoGoalAttention();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nothing from your Goals needs attention right now.'),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('today-open-goals'),
            onPressed: () => context.go('/goals'),
            child: const Text('Open Goals'),
          ),
        ],
      ),
    ),
  );
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
    required this.prayerCompletionKnown,
    required this.prayed,
    required this.recordingPrayer,
    required this.updatingAction,
    required this.onPrayerCompleted,
    required this.onActionChanged,
  });

  final TodayPrayer today;
  final bool prayerCompletionKnown;
  final bool prayed;
  final bool recordingPrayer;
  final bool updatingAction;
  final VoidCallback onPrayerCompleted;
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
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('today-prayer-complete'),
                    onPressed:
                        prayed || recordingPrayer || !prayerCompletionKnown
                        ? null
                        : onPrayerCompleted,
                    icon: Icon(
                      prayed ? Icons.check_outlined : Icons.front_hand_outlined,
                    ),
                    label: Text(
                      prayed
                          ? 'Prayed today'
                          : recordingPrayer
                          ? 'Recording…'
                          : !prayerCompletionKnown
                          ? 'Opening…'
                          : 'I prayed this',
                    ),
                  ),
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
          onPressed: updatingAction || recordingPrayer
              ? null
              : () => context.go('/prayers'),
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

class _PracticeUnavailable extends StatelessWidget {
  const _PracticeUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: Center(
      child: TextButton(
        onPressed: onRetry,
        child: const Text('Open today again'),
      ),
    ),
  );
}
