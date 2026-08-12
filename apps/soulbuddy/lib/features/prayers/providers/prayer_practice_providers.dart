import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../application/prayer_occurrence_calculator.dart';
import '../application/prayer_reminder_coordinator.dart';
import '../application/prayer_reminder_scheduler.dart';
import '../application/prayer_reminder_scheduler_factory.dart';
import '../data/powersync_prayer_practice_repository.dart';
import '../data/prayer_practice_repository.dart';
import '../domain/prayer_reminder.dart';
import '../domain/prayer_session.dart';

final prayerPracticeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final prayerDeviceTimezoneProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

final prayerOccurrenceCalculatorProvider = Provider<PrayerOccurrenceCalculator>(
  (ref) => TimezonePrayerOccurrenceCalculator.initialize(),
);

final prayerReminderSchedulerProvider = Provider<PrayerReminderScheduler>(
  (ref) => createPrayerReminderScheduler(),
);

final prayerPracticeRepositoryProvider =
    FutureProvider<PrayerPracticeRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPrayerPracticeRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
      );
    });

final prayerReminderCoordinatorProvider =
    FutureProvider<PrayerReminderCoordinator>((ref) async {
      final coordinator = PrayerReminderCoordinator(
        repository: await ref.watch(prayerPracticeRepositoryProvider.future),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
        calculator: ref.watch(prayerOccurrenceCalculatorProvider),
        clock: ref.watch(prayerPracticeClockProvider),
        timezoneName: ref.watch(prayerDeviceTimezoneProvider),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      await coordinator.start();
      return coordinator;
    });

final prayerReminderDeviceEnablerProvider =
    Provider<Future<bool> Function(String)>((ref) {
      return (reminderId) async {
        final coordinator = await ref.read(
          prayerReminderCoordinatorProvider.future,
        );
        return coordinator.enableOnThisDevice(reminderId);
      };
    });

final prayerNotificationPermissionStatusProvider =
    FutureProvider<NotificationPermissionStatus>((ref) async {
      final scheduler = ref.watch(prayerReminderSchedulerProvider);
      await ref.watch(prayerReminderCoordinatorProvider.future);
      return scheduler.permissionStatus();
    });

final prayerReminderTestProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final scheduler = ref.read(prayerReminderSchedulerProvider);
    await ref.read(prayerReminderCoordinatorProvider.future);
    await scheduler.showTestReminder();
    ref.invalidate(prayerNotificationPermissionStatusProvider);
  };
});

final prayerReminderPauseProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (reminderId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final device = await repository.watchDevice(reminderId).first;
    if (device?.enabledOnDevice == true) {
      await ref
          .read(prayerReminderSchedulerProvider)
          .cancel(device!.platformNotificationId);
    }
    await repository.setDeviceEnabled(reminderId, enabled: false);
  };
});

final prayerReminderRemoveProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (reminderId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    final device = await repository.watchDevice(reminderId).first;
    if (device?.enabledOnDevice == true) {
      await ref
          .read(prayerReminderSchedulerProvider)
          .cancel(device!.platformNotificationId);
    }
    await repository.archiveReminder(reminderId);
  };
});

final prayerReminderProvider = StreamProvider.autoDispose
    .family<PrayerReminder?, String>((ref, personalPrayerId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchReminder(personalPrayerId);
    });

final prayerReminderDeviceProvider = StreamProvider.autoDispose
    .family<PrayerReminderDevice?, String>((ref, reminderId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchDevice(reminderId);
    });

final prayerSessionCountProvider = StreamProvider.autoDispose
    .family<int, String>((ref, revisionId) async* {
      final repository = await ref.watch(
        prayerPracticeRepositoryProvider.future,
      );
      yield* repository.watchSessionCount(revisionId);
    });

final duePrayerOccurrencesProvider = StreamProvider<List<DuePrayerOccurrence>>((
  ref,
) async* {
  final coordinator = await ref.watch(prayerReminderCoordinatorProvider.future);
  yield* coordinator.dueOccurrences;
});

final prayerReminderEventsProvider =
    StreamProvider<PrayerReminderCoordinatorEvent>((ref) async* {
      final coordinator = await ref.watch(
        prayerReminderCoordinatorProvider.future,
      );
      yield* coordinator.events;
    });

final prayerReminderActionProvider =
    Provider<
      Future<PrayerSession?> Function(DuePrayerOccurrence, PrayerReminderAction)
    >((ref) {
      return (occurrence, action) async {
        final coordinator = await ref.read(
          prayerReminderCoordinatorProvider.future,
        );
        return coordinator.performAction(occurrence, action);
      };
    });

final prayerSessionRetractorProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (sessionId) async {
    final repository = await ref.read(prayerPracticeRepositoryProvider.future);
    await repository.retractSession(sessionId);
  };
});

void retryPrayerPracticeProviders(Ref ref) {
  if (ref.read(appDatabaseProvider).hasError) {
    ref.invalidate(appDatabaseProvider);
  }
  if (ref.read(localIdentityProvider).hasError) {
    ref.invalidate(localIdentityProvider);
  }
  ref.invalidate(prayerPracticeRepositoryProvider);
  ref.invalidate(prayerReminderCoordinatorProvider);
}
