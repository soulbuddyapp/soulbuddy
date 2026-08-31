import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../application/sacred_hour_alarm_permission_factory.dart';
import '../application/sacred_hour_reminder_coordinator.dart';
import '../data/powersync_sacred_hour_repository.dart';
import '../data/sacred_hour_repository.dart';
import '../domain/sacred_hour.dart';

final sacredHourRepositoryProvider = FutureProvider<SacredHourRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncSacredHourRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final sacredHourClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

final sacredHourBootstrapProvider = FutureProvider<void>((ref) async {
  final timezone = await ref.watch(prayerDeviceTimezoneProvider)();
  final repository = await ref.watch(sacredHourRepositoryProvider.future);
  await repository.ensureDefaults(timezone: timezone);
});

final activeSacredHoursProvider = StreamProvider<List<SacredHour>>((
  ref,
) async* {
  final repository = await ref.watch(sacredHourRepositoryProvider.future);
  yield* repository.watchActive();
});

final currentOrNextSacredHourProvider = StreamProvider<SacredHour?>((
  ref,
) async* {
  final now = ref.watch(sacredHourClockProvider).value ?? DateTime.now();
  final repository = await ref.watch(sacredHourRepositoryProvider.future);
  yield* repository.watchCurrentOrNext(now.toUtc());
});

final allSacredHoursProvider = StreamProvider<List<SacredHour>>((ref) async* {
  final repository = await ref.watch(sacredHourRepositoryProvider.future);
  yield* repository.watchAll();
});

final sacredHourDeliveriesProvider = StreamProvider<List<SacredHourDelivery>>((
  ref,
) async* {
  final repository = await ref.watch(sacredHourRepositoryProvider.future);
  yield* repository.watchDeliveries();
});

final sacredHourProvider = StreamProvider.autoDispose
    .family<SacredHour?, String>((ref, hourId) async* {
      final repository = await ref.watch(sacredHourRepositoryProvider.future);
      yield* repository.watch(hourId);
    });

final sacredHourReminderCoordinatorProvider =
    FutureProvider<SacredHourReminderCoordinator>((ref) async {
      await ref.watch(sacredHourBootstrapProvider.future);
      final coordinator = SacredHourReminderCoordinator(
        repository: await ref.watch(sacredHourRepositoryProvider.future),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
        exactAlarmPermission: createSacredHourAlarmPermission(),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      await coordinator.start();
      return coordinator;
    });

final sacredHourReminderEventsProvider = StreamProvider<SacredHourOpened>((
  ref,
) async* {
  final coordinator = await ref.watch(
    sacredHourReminderCoordinatorProvider.future,
  );
  yield* coordinator.events;
});
