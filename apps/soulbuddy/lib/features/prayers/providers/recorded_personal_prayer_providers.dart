import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/audio/providers/memory_audio_providers.dart';
import '../data/powersync_recorded_personal_prayer_repository.dart';
import '../data/recorded_personal_prayer_repository.dart';

final recordedPersonalPrayerRepositoryProvider =
    FutureProvider<RecordedPersonalPrayerRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      final assetStore = await ref.watch(audioAssetStoreProvider.future);
      return PowerSyncRecordedPersonalPrayerRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
        deviceId: identity.deviceId,
        assetStore: assetStore,
        soundscapePreferences: ref.watch(memorySoundscapePreferencesProvider),
      );
    });
