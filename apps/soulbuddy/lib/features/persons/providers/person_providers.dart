import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/person_repository.dart';
import '../data/powersync_person_repository.dart';
import '../application/person_prayer_reminder_coordinator.dart';
import '../domain/person_prayer_occurrence.dart';
import '../domain/prayer_person.dart';
import '../../prayers/providers/prayer_practice_providers.dart';

final personRepositoryProvider = FutureProvider<PersonRepository>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncPersonRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final prayerPeopleProvider = StreamProvider<List<PrayerPerson>>((ref) async* {
  final repository = await ref.watch(personRepositoryProvider.future);
  yield* repository.watchActive();
});

final prayerPersonProvider = StreamProvider.autoDispose
    .family<PrayerPerson?, String>((ref, id) async* {
      final repository = await ref.watch(personRepositoryProvider.future);
      yield* repository.watch(id);
    });

final duePersonPrayersProvider = StreamProvider.autoDispose
    .family<List<DuePersonPrayer>, DateTime>((ref, localDate) async* {
      final repository = await ref.watch(personRepositoryProvider.future);
      yield* repository.watchDue(localDate);
    });

final personPrayerReminderCoordinatorProvider =
    FutureProvider<PersonPrayerReminderCoordinator>((ref) async {
      final coordinator = PersonPrayerReminderCoordinator(
        repository: await ref.watch(personRepositoryProvider.future),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
        timezoneName: ref.watch(prayerDeviceTimezoneProvider),
        clock: ref.watch(prayerPracticeClockProvider),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      await coordinator.start();
      return coordinator;
    });

final personPrayerReminderEventsProvider =
    StreamProvider<PersonPrayerReminderOpened>((ref) async* {
      final coordinator = await ref.watch(
        personPrayerReminderCoordinatorProvider.future,
      );
      yield* coordinator.events;
    });

final enablePersonPrayerRemindersProvider = Provider<Future<bool> Function()>((
  ref,
) {
  return () async {
    final coordinator = await ref.read(
      personPrayerReminderCoordinatorProvider.future,
    );
    return coordinator.enable();
  };
});
