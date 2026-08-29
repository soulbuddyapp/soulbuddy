import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/personal_prayer_repository.dart';
import '../data/powersync_personal_prayer_repository.dart';
import '../data/powersync_prayer_generation_repository.dart';
import '../data/prayer_generation_repository.dart';
import '../domain/personal_prayer.dart';

final prayerGenerationRepositoryProvider =
    FutureProvider<PrayerGenerationRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPrayerGenerationRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
      );
    });

final personalPrayerRepositoryProvider =
    FutureProvider<PersonalPrayerRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncPersonalPrayerRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
      );
    });

final personalPrayerProvider = StreamProvider.autoDispose
    .family<PersonalPrayer?, String>((ref, prayerId) async* {
      final repository = await ref.watch(
        personalPrayerRepositoryProvider.future,
      );
      yield* repository.watch(prayerId);
    });
