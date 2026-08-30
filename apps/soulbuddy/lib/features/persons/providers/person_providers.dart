import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/person_repository.dart';
import '../data/powersync_person_repository.dart';
import '../domain/person_prayer_occurrence.dart';
import '../domain/prayer_person.dart';

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
