import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../../core/presentation/covenant_slabs.dart';
import '../../../core/presentation/sanctuary_artwork.dart';
import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_providers.dart';
import 'completed_today_item.dart';
import '../../altar/presentation/altar_today_card.dart';
import '../../goals/application/goal_today_composer.dart';
import '../../goals/application/goal_today_resource_adapter.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_today_sections.dart';
import '../../goals/presentation/today_prayer_goal_migration_card.dart';
import '../../goals/providers/goal_providers.dart';
import '../../goals/providers/goal_today_providers.dart';
import '../../formation/presentation/formation_today_card.dart';
import '../../prayers/application/prayer_reminder_scheduler.dart';
import '../../prayers/domain/prayer_reference.dart';
import '../../prayers/domain/today_prayer.dart';
import '../../prayers/presentation/prayer_library_tile.dart';
import '../../prayers/presentation/prayer_reminder_card.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../../prayers/providers/personal_prayer_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../remember/presentation/daily_remembrance_card.dart';
import '../../remember/providers/daily_memory_providers.dart';
import '../../record/presentation/inline_memory_recorder.dart';
import '../../sacred_hours/application/sacred_hour_today_window.dart';
import '../../sacred_hours/domain/sacred_hour.dart';
import '../../sacred_hours/presentation/sacred_hour_today_card.dart';
import '../../sacred_hours/providers/sacred_hour_providers.dart';
import '../domain/daily_practice_state.dart';
import '../providers/daily_practice_providers.dart';
import 'today_start_guide.dart';
import '../providers/today_guidance_providers.dart';
import 'today_guidance_card.dart';
import '../../scripture/presentation/daily_scripture_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({this.focusAltar = false, super.key});

  final bool focusAltar;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  var _updatingAction = false;
  var _recordingPrayer = false;
  var _recordingMemory = false;
  var _quickReflection = false;
  final _dismissedCompletions = <String>{};
  final _completionTimes = <String, DateTime>{};
  final _altarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focusAltarIfRequested();
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusAltar && !oldWidget.focusAltar) {
      _focusAltarIfRequested();
    }
  }

  void _focusAltarIfRequested() {
    if (!widget.focusAltar) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final altarContext = _altarKey.currentContext;
      if (altarContext != null) {
        Scrollable.ensureVisible(
          altarContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.08,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayPrayer = ref.watch(todayPrayerProvider);
    final personalPrayers = ref.watch(personalPrayersProvider);
    final dailyMemory = ref.watch(dailyMemoryProvider);
    final dailyPractices = ref.watch(dailyPracticeStateProvider);
    final goalToday = ref.watch(goalTodaySnapshotProvider);
    final guidance = ref.watch(todayGuidanceProvider);
    final goalSnapshot = switch (goalToday) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final goalsKnownEmpty = switch (goalToday) {
      AsyncData(:final value) => value.activeGoalCount == 0,
      _ => false,
    };
    final prayersKnownEmpty = switch (personalPrayers) {
      AsyncData(:final value) => value.isEmpty,
      _ => false,
    };
    final noPrayerSelected = switch (todayPrayer) {
      AsyncData(value: null) => true,
      _ => false,
    };
    final showStartGuide =
        goalsKnownEmpty && prayersKnownEmpty && noPrayerSelected;
    final showLegacyPrayer =
        !showStartGuide ||
        goalSnapshot?.resources.legacyTodayOutsideActiveGoals != null;
    final showDailyMemory =
        !showStartGuide ||
        switch (dailyMemory) {
          AsyncData(:final value) => value != null,
          AsyncError() => true,
          _ => false,
        };

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
              Padding(
                padding: const EdgeInsets.only(right: 48, top: 12),
                child: Semantics(
                  header: true,
                  child: Text(
                    '${DateTime.now().hour < 12
                        ? 'Good morning'
                        : DateTime.now().hour < 18
                        ? 'Good afternoon'
                        : 'Good evening'},\nBeloved',
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'BE TRANSFORMED · ROMANS 12:2',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1.7),
              ),
              const SizedBox(height: 24),
              IgnorePointer(
                ignoring: _recordingMemory,
                child: const FormationTodayCard(),
              ),
              IgnorePointer(
                ignoring: _recordingMemory,
                child: const DailyScriptureCard(),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final single =
                      MediaQuery.textScalerOf(context).scale(16) > 23;
                  final width = single
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: SanctuaryPracticeTile(
                          art: SanctuaryArt.prayer,
                          title: 'Quiet prayer',
                          onTap: () {
                            if (!_recordingMemory) {
                              context.push('/prayer/quiet');
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SanctuaryPracticeTile(
                          art: SanctuaryArt.scripture,
                          title: 'Scripture',
                          onTap: () {
                            if (!_recordingMemory) {
                              context.push('/scripture/daily');
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SanctuaryPracticeTile(
                          art: SanctuaryArt.renewal,
                          title: 'Reflect',
                          onTap: () {
                            if (!_recordingMemory) {
                              setState(() => _quickReflection = true);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_quickReflection) ...[
                const SizedBox(height: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InlineMemoryRecorder(
                      label: 'Record reflection',
                      initialTitle: 'Reflection',
                      privateReflection: true,
                      onBusyChanged: (busy) {
                        if (mounted) {
                          setState(() {
                            _recordingMemory = busy;
                            if (!busy) _quickReflection = false;
                          });
                        }
                      },
                    ),
                    if (!_recordingMemory)
                      TextButton(
                        onPressed: () =>
                            setState(() => _quickReflection = false),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 26),
              Text('Today', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
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
              guidance.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (value) => showStartGuide
                    ? const SizedBox.shrink()
                    : TodayGuidanceCard(
                        guidance: value,
                        onOpen: () {
                          if (_recordingMemory) return;
                          if (value.route == '/persons/new' ||
                              value.route == '/welcome/goal') {
                            context.push(value.route);
                          } else {
                            context.go(value.route);
                          }
                        },
                        actionControl: value.route == '/remember/capture'
                            ? InlineMemoryRecorder(
                                buttonKey: const Key('today-guidance-action'),
                                label: value.actionLabel,
                                enabled: !_recordingMemory,
                                onBusyChanged: (busy) {
                                  if (mounted) {
                                    setState(() => _recordingMemory = busy);
                                  }
                                },
                              )
                            : null,
                      ),
              ),
              IgnorePointer(
                ignoring: _recordingMemory,
                child: const _SacredHourTodaySection(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (goalSnapshot != null) ...[
                if (goalSnapshot.sections.isNotEmpty)
                  IgnorePointer(
                    ignoring: _recordingMemory,
                    child: GoalTodaySections(
                      snapshot: goalSnapshot,
                      excludedGoalIds: {
                        for (final section in goalSnapshot.sections)
                          if (section.goal.starterKey ==
                              GoalStarterKey.closerToGod)
                            section.goal.id,
                      },
                      onCompleteAction: (item) =>
                          _completeGoalAction(goalSnapshot, item),
                      onOpenResource: _openGoalResource,
                      onCompleteResource: _completeGoalResource,
                    ),
                  )
                else if (goalSnapshot.activeGoalCount > 0)
                  IgnorePointer(
                    ignoring: _recordingMemory,
                    child: const _NoGoalAttention(),
                  ),
                if (goalSnapshot
                    .resources
                    .dueRemindersOutsideActiveGoals
                    .isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  IgnorePointer(
                    ignoring: _recordingMemory,
                    child: PrayerReminderCard(
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
                          MediaQuery.maybeOf(context)?.disableAnimations ??
                          false,
                    ),
                  ),
                ],
                if (goalSnapshot.sections.isNotEmpty ||
                    goalSnapshot.activeGoalCount > 0 ||
                    goalSnapshot
                        .resources
                        .dueRemindersOutsideActiveGoals
                        .isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
              ],
              KeyedSubtree(
                key: _altarKey,
                child: IgnorePointer(
                  ignoring: _recordingMemory,
                  child: const AltarTodaySection(),
                ),
              ),
              SizedBox(height: showStartGuide ? AppSpacing.sm : AppSpacing.md),
              if (showStartGuide)
                TodayStartGuide(
                  onStartGoal: _recordingMemory
                      ? null
                      : () => context.push('/welcome/goal'),
                  recordControl: InlineMemoryRecorder(
                    buttonKey: const Key('today-record-memory'),
                    label: 'Record something',
                    enabled: !_recordingMemory,
                    onBusyChanged: (busy) {
                      if (mounted) setState(() => _recordingMemory = busy);
                    },
                  ),
                ),
              if (showLegacyPrayer) ...[
                if (showStartGuide) const SizedBox(height: AppSpacing.md),
                IgnorePointer(
                  ignoring: _recordingMemory,
                  child: _legacyTodayContent(
                    todayPrayer: todayPrayer,
                    dailyPractices: dailyPractices,
                    goalSnapshot: goalSnapshot,
                  ),
                ),
              ],
              if (showDailyMemory) ...[
                const SizedBox(height: AppSpacing.lg),
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
                      ? InlineMemoryRecorder(
                          buttonKey: const Key('record-something-to-remember'),
                          label: 'Record something to remember',
                          enabled: !_recordingMemory,
                          onBusyChanged: (busy) {
                            if (mounted) {
                              setState(() => _recordingMemory = busy);
                            }
                          },
                        )
                      : IgnorePointer(
                          ignoring: _recordingMemory,
                          child: DailyRemembranceCard(dailyMemory: daily),
                        ),
                ),
              ],
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
      error: (error, stackTrace) =>
          _TodayUnavailable(onRetry: () => retryTodayPrayerProvider(ref)),
      data: (today) => today == null
          ? const _NoPrayerSelected()
          : _selectedLegacyPrayer(today, dailyPractices),
    );
  }

  Widget _selectedLegacyPrayer(
    TodayPrayer today,
    AsyncValue<DailyPracticeState> dailyPractices,
  ) {
    final date = today.localDate;
    final dayKey = '${date.year}-${date.month}-${date.day}';
    final prayerCompletionId =
        'legacy-prayer-$dayKey-${today.prayer.reference.id}';
    final actionCompletionId =
        'legacy-action-$dayKey-${today.prayer.reference.id}';
    final prayed =
        dailyPractices.value?.completed.contains(DailyPractice.pray) ?? false;
    final prayerCompletedAt = prayed
        ? _completionTimes.putIfAbsent(prayerCompletionId, DateTime.now)
        : null;
    final actionCompletedAt = today.actionCompleted
        ? _completionTimes.putIfAbsent(actionCompletionId, DateTime.now)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TodayPrayerGoalMigrationCard(today: today),
        _SelectedPrayer(
          today: today,
          prayerCompletionKnown:
              dailyPractices is AsyncData<DailyPracticeState>,
          prayed: prayed,
          recordingPrayer: _recordingPrayer,
          updatingAction: _updatingAction,
          prayerCompletionId: prayerCompletionId,
          actionCompletionId: actionCompletionId,
          prayerCompletedAt: prayerCompletedAt,
          actionCompletedAt: actionCompletedAt,
          showPrayerCompletion: !_dismissedCompletions.contains(
            prayerCompletionId,
          ),
          showActionCompletion: !_dismissedCompletions.contains(
            actionCompletionId,
          ),
          onDismissCompletion: (id) =>
              setState(() => _dismissedCompletions.add(id)),
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
      rethrow;
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
    if (!mounted || _recordingMemory) return;
    switch (handle) {
      case GoalTodayReminderHandle(:final occurrence):
        context.push('/prayers/saved/${occurrence.reminder.personalPrayerId}');
      case GoalTodayLinkedPrayerHandle(:final prayer):
        _openPrayerReference(prayer);
      case GoalTodayLegacyPrayerHandle(:final today):
        _openPrayerReference(today.prayer.reference);
      case GoalTodayScriptureHandle(:final link):
        final book = Uri.encodeComponent(link.book!);
        context.push('/remember/scripture/$book/${link.chapter}');
      case null:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This resource could not be opened.')),
        );
    }
  }

  void _openPrayerReference(PrayerReference prayer) {
    if (_recordingMemory) return;
    final route = switch (prayer.source) {
      PrayerSource.personal => '/prayers/saved/${prayer.id}',
      PrayerSource.library => '/prayers/${prayer.id}',
    };
    context.push(route);
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
          final sessionId = await _recordPrayerSession(
            today,
            idempotencyKey: _goalTodayPrayerIdempotencyKey(today),
          );
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
      rethrow;
    }
  }

  String _goalTodayPrayerIdempotencyKey(TodayPrayer today) {
    final prayer = today.prayer.reference;
    final date = today.localDate;
    final localDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return 'goal-today:$localDate:${prayer.source.name}:${prayer.id}';
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

  Future<String> _recordPrayerSession(
    TodayPrayer displayedToday, {
    String? idempotencyKey,
  }) async {
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
      idempotencyKey: idempotencyKey,
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

class _SacredHourTodaySection extends ConsumerWidget {
  const _SacredHourTodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentOrNextSacredHourProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (hour) {
            if (hour == null) return const SizedBox.shrink();
            final now =
                ref.watch(sacredHourClockProvider).value ?? DateTime.now();
            final window = SacredHourTodayWindow.classify(hour, now);
            if (window.phase == SacredHourTodayPhase.hidden) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _SacredHourTodayCardWithStatus(
                hour: hour,
                now: now,
                window: window,
                onOpen: () => unawaited(
                  _openSacredHourFromToday(context, ref, hour, window),
                ),
              ),
            );
          },
        );
  }
}

class _SacredHourTodayCardWithStatus extends ConsumerWidget {
  const _SacredHourTodayCardWithStatus({
    required this.hour,
    required this.now,
    required this.window,
    required this.onOpen,
  });
  final SacredHour hour;
  final DateTime now;
  final SacredHourTodayWindow window;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = window.phase == SacredHourTodayPhase.active
        ? ref
              .watch(
                sacredHourOccurrenceStatusProvider((
                  hourId: hour.id,
                  dueAt: window.startsAtUtc,
                )),
              )
              .value
        : null;
    return SacredHourTodayCard(
      hour: hour,
      nowUtc: now,
      completed: status == SacredHourOccurrenceStatus.completed,
      onOpen: onOpen,
    );
  }
}

Future<void> _openSacredHourFromToday(
  BuildContext context,
  WidgetRef ref,
  SacredHour hour,
  SacredHourTodayWindow window,
) async {
  final occurrence = '${hour.id}@${window.startsAtUtc.toIso8601String()}';
  final route = Uri(
    pathSegments: ['sacred-hours', hour.id],
    queryParameters: {'occurrence': occurrence},
  ).toString();
  if (window.phase == SacredHourTodayPhase.active) {
    await ref
        .read(spiritualSessionControllerProvider)
        .begin(
          SpiritualSession(
            id: 'sacred-hour:$occurrence',
            kind: SpiritualSessionKind.sacredHour,
            title: hour.name,
            route: route,
            canPause: false,
            completionLabel: 'Complete',
            onPause: () async {},
            onResume: () async {},
            onComplete: () async {
              final repository = await ref.read(
                sacredHourRepositoryProvider.future,
              );
              await repository.markOccurrence(
                hour.id,
                window.startsAtUtc,
                SacredHourOccurrenceStatus.completed,
              );
            },
            onClose: () async {},
          ),
        );
  }
  if (context.mounted) context.push(route);
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
    required this.prayerCompletionId,
    required this.actionCompletionId,
    required this.prayerCompletedAt,
    required this.actionCompletedAt,
    required this.showPrayerCompletion,
    required this.showActionCompletion,
    required this.onDismissCompletion,
  });

  final TodayPrayer today;
  final bool prayerCompletionKnown;
  final bool prayed;
  final bool recordingPrayer;
  final bool updatingAction;
  final VoidCallback onPrayerCompleted;
  final ValueChanged<bool> onActionChanged;
  final String prayerCompletionId;
  final String actionCompletionId;
  final DateTime? prayerCompletedAt;
  final DateTime? actionCompletedAt;
  final bool showPrayerCompletion;
  final bool showActionCompletion;
  final ValueChanged<String> onDismissCompletion;

  @override
  Widget build(BuildContext context) {
    final prayer = today.prayer;
    final action = prayer.action?.trim();
    final showsAction =
        today.includeAction && action != null && action.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prayed && showPrayerCompletion)
          CompletedTodayItem(
            id: prayerCompletionId,
            label: '${prayer.title} · Prayed',
            completedAt: prayerCompletedAt!,
            onDismiss: () => onDismissCompletion(prayerCompletionId),
          )
        else if (!prayed)
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
                        prayed
                            ? Icons.check_outlined
                            : Icons.front_hand_outlined,
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
        if (showsAction && today.actionCompleted && showActionCompletion) ...[
          const SizedBox(height: AppSpacing.md),
          CompletedTodayItem(
            id: actionCompletionId,
            label: action,
            completedAt: actionCompletedAt!,
            onDismiss: () => onDismissCompletion(actionCompletionId),
          ),
        ] else if (showsAction && !today.actionCompleted) ...[
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
