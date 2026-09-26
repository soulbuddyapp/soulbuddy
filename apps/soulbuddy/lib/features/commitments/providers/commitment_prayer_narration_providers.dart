import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../prayers/domain/prayer_narration.dart';
import '../../prayers/providers/prayer_practice_providers.dart';
import '../data/commitment_personal_prayer_narration_cache_repository.dart';
import '../data/powersync_commitment_personal_prayer_narration_cache_repository.dart';

final commitmentPrayerNarrationCacheProvider =
    FutureProvider<CommitmentPersonalPrayerNarrationCacheRepository>((
      ref,
    ) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncCommitmentPersonalPrayerNarrationCacheRepository(
        database: db.powersync,
        ownerId: identity.ownerId,
      );
    });
final commitmentPreparePrayerProvider =
    Provider<
      Future<void> Function({
        required String personalPrayerId,
        required String revisionId,
        required bool consent,
      })
    >((ref) {
      return ({
        required personalPrayerId,
        required revisionId,
        required consent,
      }) async {
        final narration =
            await ref.read(preparePersonalPrayerNarrationProvider)(
              personalPrayerId: personalPrayerId,
              revisionId: revisionId,
              consent: consent,
            );
        final identity = await ref.read(localIdentityProvider.future);
        final cache = await ref.read(
          commitmentPrayerNarrationCacheProvider.future,
        );
        await cache.save(
          commitmentId: 'draft',
          personalPrayerId: personalPrayerId,
          deviceId: identity.deviceId,
          narration: narration,
          consent: consent,
        );
      };
    });
final commitmentPreparedPrayerProvider = FutureProvider.autoDispose
    .family<PrayerNarration?, String>((ref, commitmentId) async {
      try {
        final identity = await ref.watch(localIdentityProvider.future);
        final cache = await ref.watch(
          commitmentPrayerNarrationCacheProvider.future,
        );
        return await cache.load(
          commitmentId: commitmentId,
          deviceId: identity.deviceId,
        );
      } catch (_) {
        return null;
      }
    });
