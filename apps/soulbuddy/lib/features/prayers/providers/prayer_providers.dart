import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/bundled_prayer_importer.dart';
import '../data/powersync_prayer_repository.dart';
import '../data/prayer_repository.dart';
import '../domain/library_prayer.dart';
import '../domain/today_prayer.dart';

typedef PrayerLibraryFilter = ({
  PrayerGrounding? grounding,
  PrayerPurpose? purpose,
});

typedef PrayerLocalDate = ({int year, int month, int day});

final prayerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final todayPrayerDateProvider = StreamProvider.autoDispose<PrayerLocalDate>((
  ref,
) {
  final clock = ref.watch(prayerClockProvider);
  Timer? rolloverTimer;
  var disposed = false;
  late final StreamController<PrayerLocalDate> controller;

  void emitDateAndScheduleRollover() {
    if (disposed) return;
    final now = clock();
    controller.add((year: now.year, month: now.month, day: now.day));
    final nextLocalMidnight = DateTime(now.year, now.month, now.day + 1);
    rolloverTimer?.cancel();
    rolloverTimer = Timer(
      nextLocalMidnight.difference(now),
      emitDateAndScheduleRollover,
    );
  }

  controller = StreamController<PrayerLocalDate>(
    sync: true,
    onListen: emitDateAndScheduleRollover,
    onCancel: () {
      disposed = true;
      rolloverTimer?.cancel();
    },
  );
  ref.onDispose(() {
    disposed = true;
    rolloverTimer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

final prayerRepositoryProvider = FutureProvider<PrayerRepository>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  await BundledPrayerImporter().ensureLoaded(database.powersync);

  return PowerSyncPrayerRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
  );
});

final prayerLibraryProvider = StreamProvider.autoDispose
    .family<List<LibraryPrayer>, PrayerLibraryFilter>((ref, filter) async* {
      final repository = await ref.watch(prayerRepositoryProvider.future);
      yield* repository.watchLibrary(
        grounding: filter.grounding,
        purpose: filter.purpose,
      );
    });

final prayerProvider = StreamProvider.autoDispose
    .family<LibraryPrayer?, String>((ref, prayerId) async* {
      final repository = await ref.watch(prayerRepositoryProvider.future);
      yield* repository.watchPrayer(prayerId);
    });

final todayPrayerProvider = StreamProvider.autoDispose<TodayPrayer?>((
  ref,
) async* {
  switch (ref.watch(todayPrayerDateProvider)) {
    case AsyncData(:final value):
      final repository = await ref.watch(prayerRepositoryProvider.future);
      yield* repository.watchToday(
        DateTime(value.year, value.month, value.day),
      );
    case AsyncError(:final error, :final stackTrace):
      Error.throwWithStackTrace(error, stackTrace);
    case AsyncLoading():
      return;
  }
});

void retryPrayerLibraryProviders(WidgetRef ref, PrayerLibraryFilter filter) {
  _invalidatePrayerStartup(ref);
  ref.invalidate(prayerLibraryProvider(filter));
}

void retryPrayerDetailProviders(WidgetRef ref, String prayerId) {
  _invalidatePrayerStartup(ref);
  ref.invalidate(prayerProvider(prayerId));
}

void retryTodayPrayerProvider(WidgetRef ref) {
  _invalidatePrayerStartup(ref);
  ref.invalidate(todayPrayerProvider);
}

void _invalidatePrayerStartup(WidgetRef ref) {
  final databaseState = ref.read(appDatabaseProvider);
  final identityState = ref.read(localIdentityProvider);

  if (databaseState.hasError) {
    ref.invalidate(appDatabaseProvider);
  }
  if (identityState.hasError) {
    ref.invalidate(localIdentityProvider);
  }
  ref.invalidate(prayerRepositoryProvider);
}
