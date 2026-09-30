import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/altar/providers/altar_ritual_providers.dart';
import '../../features/circles/providers/circle_providers.dart';
import '../../features/commitments/providers/commitment_reminder_providers.dart';
import '../../features/daily_formation/providers/daily_formation_providers.dart';
import '../../features/goals/providers/goal_meditation_providers.dart';
import '../../features/persons/providers/person_providers.dart';
import '../../features/prayers/providers/prayer_practice_providers.dart';
import '../../features/sacred_hours/providers/sacred_hour_providers.dart';
import 'local_reminder_recovery.dart';

final localReminderRecoveryProvider = Provider<LocalReminderRecovery>((ref) {
  final scheduler = ref.watch(prayerReminderSchedulerProvider);

  Future<void> recover<T>(
    FutureProvider<T> provider,
    Future<void> Function(T) refresh,
  ) async {
    // Failed startup providers need a new coordinator, with fresh subscriptions.
    if (ref.read(provider).hasError) ref.invalidate(provider);
    final coordinator = await ref.read(provider.future);
    if (ref.mounted) await refresh(coordinator);
  }

  final recovery = LocalReminderRecovery(
    initialize: scheduler.initialize,
    permissionStatus: scheduler.permissionStatus,
    recover: [
      () => recover(prayerReminderCoordinatorProvider, (c) => c.reconcileNow()),
      () => recover(sacredHourReminderCoordinatorProvider, (c) => c.refresh()),
      () =>
          recover(personPrayerReminderCoordinatorProvider, (c) => c.refresh()),
      () => recover(altarReminderCoordinatorProvider, (c) => c.refresh()),
      () => recover(circleReminderCoordinatorProvider, (c) => c.refresh()),
      () => recover(
        dailyFormationReminderCoordinatorProvider,
        (c) => c.reconcile(),
      ),
      () => recover(
        goalMeditationReminderCoordinatorProvider,
        (c) => c.reconcile(),
      ),
      () => recover(commitmentReminderCoordinatorProvider, (c) => c.refresh()),
    ],
  );
  ref.onDispose(recovery.dispose);
  recovery.start();
  return recovery;
});
