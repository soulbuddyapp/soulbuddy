import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/bundled_prayer_importer.dart';
import '../data/powersync_prayer_repository.dart';
import '../data/prayer_repository.dart';
import '../domain/library_prayer.dart';

typedef PrayerLibraryFilter = ({
  PrayerGrounding? grounding,
  PrayerPurpose? purpose,
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

final prayerLibraryProvider =
    StreamProvider.family<List<LibraryPrayer>, PrayerLibraryFilter>((
      ref,
      filter,
    ) async* {
      final repository = await ref.watch(prayerRepositoryProvider.future);
      yield* repository.watchLibrary(
        grounding: filter.grounding,
        purpose: filter.purpose,
      );
    });

final prayerProvider = StreamProvider.family<LibraryPrayer?, String>((
  ref,
  prayerId,
) async* {
  final repository = await ref.watch(prayerRepositoryProvider.future);
  yield* repository.watchPrayer(prayerId);
});
