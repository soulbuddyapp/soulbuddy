import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/prayer_release_api_client.dart';
import '../data/prayer_release_narration_repository.dart';
import '../data/prayer_release_repository.dart';
import '../data/powersync_prayer_release_repository.dart';
import '../domain/prayer_release.dart';

/// A refresh should not be attempted until it has been needed, so discovery is
/// one-shot rather than polled.
final prayerReleaseRepositoryProvider = FutureProvider<PrayerReleaseRepository>(
  (ref) async {
    final database = await ref.watch(appDatabaseProvider.future);
    final identity = await ref.watch(localIdentityProvider.future);
    final client = ref.watch(prayerReleaseApiClientProvider);

    return PowerSyncPrayerReleaseRepository(
      database: database.powersync,
      ownerId: identity.ownerId,
      client: client,
    );
  },
);

final prayerReleaseApiClientProvider = Provider<PrayerReleaseApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return PrayerReleaseApiClient(
    apiBaseUri: Uri.tryParse(AppConfig.apiBaseUrl) ?? Uri(),
    accessToken: ref.watch(appSessionTokenReaderProvider),
    httpClient: client,
  );
});

/// Keeps the discovery metadata and preference fresh without a permanent watch.
final prayerReleaseRefreshProvider = FutureProvider<void>((ref) async {
  final repository = await ref.watch(prayerReleaseRepositoryProvider.future);
  await repository.refresh();
});

/// Every discovered release, so an unadded one can still be offered.
final discoveredPrayerReleasesProvider = StreamProvider.autoDispose((
  ref,
) async* {
  final repository = await ref.watch(prayerReleaseRepositoryProvider.future);
  yield* repository.watchReleases();
});

final addedPrayerReleasesProvider = StreamProvider.autoDispose((ref) async* {
  final repository = await ref.watch(prayerReleaseRepositoryProvider.future);
  yield* repository.watchAddedReleases();
});

final prayerReleaseProvider = StreamProvider.autoDispose
    .family<PrayerRelease?, String>((ref, slug) async* {
      final repository = await ref.watch(
        prayerReleaseRepositoryProvider.future,
      );
      yield* repository.watchRelease(slug);
    });

final prayerReleaseContentProvider = StreamProvider.autoDispose
    .family<List<PrayerReleaseItemContent>, String>((ref, slug) async* {
      final repository = await ref.watch(
        prayerReleaseRepositoryProvider.future,
      );
      yield* repository.watchReleaseContent(slug);
    });

/// The added release item content for this canonical prayer, if any.
final prayerReleaseItemContentProvider = StreamProvider.autoDispose
    .family<PrayerReleaseItemContent?, String>((ref, prayerId) async* {
      final repository = await ref.watch(
        prayerReleaseRepositoryProvider.future,
      );
      yield* repository.watchContentForPrayer(prayerId);
    });

final prayerReleasePreferenceProvider = StreamProvider.autoDispose((
  ref,
) async* {
  final repository = await ref.watch(prayerReleaseRepositoryProvider.future);
  yield* repository.watchPreference();
});

/// Narration for a release item, served only for validated transcript content.
final prayerReleaseNarrationRepositoryProvider =
    Provider<PrayerReleaseNarrationRepository>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);

      return LaravelPrayerReleaseNarrationRepository(
        apiBaseUri: Uri.tryParse(AppConfig.apiBaseUrl) ?? Uri(),
        accessToken: ref.watch(appSessionTokenReaderProvider),
        httpClient: client,
      );
    });

/// Retries only the failed refresh, leaving the cached content in place.
void retryPrayerReleaseRefresh(WidgetRef ref) {
  ref.invalidate(prayerReleaseRefreshProvider);
}
