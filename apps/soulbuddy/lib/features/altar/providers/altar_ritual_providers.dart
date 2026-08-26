import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/providers/prayer_providers.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../application/altar_reminder_coordinator.dart';
import '../data/altar_ritual_repository.dart';
import '../data/powersync_altar_ritual_repository.dart';
import '../domain/altar_ritual.dart';

final altarRitualRepositoryProvider = FutureProvider<AltarRitualRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return PowerSyncAltarRitualRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final altarRitualForTargetProvider = StreamProvider.autoDispose
    .family<AltarRitual?, AltarTarget>((ref, target) async* {
      final repository = await ref.watch(altarRitualRepositoryProvider.future);
      yield* repository.watchForTarget(target);
    });

final altarClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});

final dueAltarRitualProvider = StreamProvider.autoDispose<DueAltarRitual?>((
  ref,
) async* {
  final displayedDate = await ref.watch(todayPrayerDateProvider.future);
  final repository = await ref.watch(altarRitualRepositoryProvider.future);
  final now = ref.watch(altarClockProvider).value ?? DateTime.now();
  yield* repository.watchNextForDate(
    DateTime(displayedDate.year, displayedDate.month, displayedDate.day),
    now: now,
  );
});

final altarReminderCoordinatorProvider =
    FutureProvider<AltarReminderCoordinator>((ref) async {
      final coordinator = AltarReminderCoordinator(
        repository: await ref.watch(altarRitualRepositoryProvider.future),
        scheduler: ref.watch(prayerReminderSchedulerProvider),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      await coordinator.start();
      return coordinator;
    });

final altarReminderEventsProvider = StreamProvider<AltarReminderOpened>((
  ref,
) async* {
  final coordinator = await ref.watch(altarReminderCoordinatorProvider.future);
  yield* coordinator.events;
});

class PendingAltarOpenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String ritualId) => state = ritualId;
  void clear() => state = null;
}

final pendingAltarOpenProvider =
    NotifierProvider<PendingAltarOpenNotifier, String?>(
      PendingAltarOpenNotifier.new,
    );

class AltarAutoplayClaimNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  bool claim(String occurrenceKey) {
    if (state == occurrenceKey) return false;
    state = occurrenceKey;
    return true;
  }
}

final altarAutoplayClaimProvider =
    NotifierProvider<AltarAutoplayClaimNotifier, String?>(
      AltarAutoplayClaimNotifier.new,
    );
