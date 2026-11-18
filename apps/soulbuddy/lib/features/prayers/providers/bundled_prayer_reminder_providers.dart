import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../application/bundled_prayer_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../application/bundled_prayer_reminder.dart';
import 'prayer_practice_providers.dart';
import 'prayer_providers.dart';

final bundledPrayerReminderProvider = FutureProvider<BundledPrayerReminder>((
  ref,
) async {
  final storage = ref.watch(secureStorageProvider);
  final service = BundledPrayerReminder(
    scheduler: ref.watch(prayerReminderSchedulerProvider),
    read: () => storage.read(key: 'bundled-prayer-reminders.v1'),
    write: (value) =>
        storage.write(key: 'bundled-prayer-reminders.v1', value: value),
    timezoneName: ref.watch(prayerDeviceTimezoneProvider),
    clock: DateTime.now,
    isEligible: (id) async {
      final data =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/content/prayer_library.json',
                ),
              )
              as Map;
      final prayers = (data['prayers'] as List).whereType<Map>();
      for (final prayer in prayers) {
        if (prayer['id'] == id && prayer['body'] is String) {
          return (await BundledPrayerAudioCatalog.load()).assetFor(
                id,
                prayer['body'] as String,
              ) !=
              null;
        }
      }
      return false;
    },
  );
  ref.listen(prayerAppResumeProvider, (previous, next) {
    if (next is AsyncData<int>) {
      unawaited(service.reconcile().catchError((_) {}));
    }
  });
  ref.onDispose(() => unawaited(service.close()));
  await service.start();
  return service;
});
final bundledPrayerReminderEventsProvider = StreamProvider<String>((
  ref,
) async* {
  final service = await ref.watch(bundledPrayerReminderProvider.future);
  yield* service.events;
});
final bundledPrayerReminderTimeProvider = FutureProvider.autoDispose
    .family<(int, int)?, String>(
      (ref, id) async =>
          (await ref.watch(bundledPrayerReminderProvider.future)).timeFor(id),
    );

final bundledPrayerReminderAudioProvider = FutureProvider.autoDispose
    .family<bool, String>(
      (ref, id) async => (await ref.watch(
        bundledPrayerReminderProvider.future,
      )).audioEnabledFor(id),
    );
