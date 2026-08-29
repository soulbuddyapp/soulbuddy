import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../../record/providers/encounter_providers.dart';
import '../application/legacy_circle_migration_service.dart';
import '../data/circle_directory_repository.dart';
import '../data/laravel_circle_directory_repository.dart';
import '../data/legacy_circle_migration_repository.dart';
import '../data/powersync_legacy_circle_migration_repository.dart';
import '../domain/circle.dart';
import '../domain/legacy_circle.dart';

final circleHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final circleDirectoryRepositoryProvider =
    FutureProvider<CircleDirectoryRepository>((ref) async {
      await ref.watch(installationSessionBootstrapProvider.future);
      final base = Uri.tryParse(AppConfig.apiBaseUrl);
      if (base == null || !base.hasScheme) {
        throw const CircleDirectoryUnavailable();
      }
      return LaravelCircleDirectoryRepository(
        apiBaseUri: base,
        tokenReader: ref.watch(appSessionTokenReaderProvider),
        client: ref.watch(circleHttpClientProvider),
      );
    });

final circleDiscoveryProvider = FutureProvider.autoDispose
    .family<CirclePage, CircleDiscoveryQuery>((ref, query) async {
      final repository = await ref.watch(
        circleDirectoryRepositoryProvider.future,
      );
      return repository.discover(query);
    });

final ownedCirclesProvider = FutureProvider.autoDispose<List<Circle>>((
  ref,
) async {
  final repository = await ref.watch(circleDirectoryRepositoryProvider.future);
  return repository.listOwned();
});

final circleProvider = FutureProvider.autoDispose.family<Circle?, String>((
  ref,
  publicId,
) async {
  final repository = await ref.watch(circleDirectoryRepositoryProvider.future);
  return repository.get(publicId);
});

final legacyCircleMigrationRepositoryProvider =
    FutureProvider<LegacyCircleMigrationRepository>((ref) async {
      final database = await ref.watch(appDatabaseProvider.future);
      final identity = await ref.watch(localIdentityProvider.future);
      return PowerSyncLegacyCircleMigrationRepository(
        database: database.powersync,
        ownerId: identity.ownerId,
      );
    });

final legacyCirclesProvider =
    FutureProvider.autoDispose<List<LegacyCircleSummary>>((ref) async {
      final repository = await ref.watch(
        legacyCircleMigrationRepositoryProvider.future,
      );
      return repository.list();
    });

final legacyCircleArchiveProvider = FutureProvider.autoDispose
    .family<LegacyCircleArchive?, String>((ref, circleId) async {
      final repository = await ref.watch(
        legacyCircleMigrationRepositoryProvider.future,
      );
      return repository.read(circleId);
    });

final legacyCircleMigrationServiceProvider =
    FutureProvider<LegacyCircleMigrationService>((ref) async {
      return LegacyCircleMigrationService(
        legacyRepository: await ref.watch(
          legacyCircleMigrationRepositoryProvider.future,
        ),
        encounterRepository: await ref.watch(
          encounterRepositoryProvider.future,
        ),
      );
    });

typedef CircleExternalLauncher = Future<bool> Function(Uri uri);

final circleExternalLauncherProvider = Provider<CircleExternalLauncher>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

void invalidateCircleDirectory(Ref ref) {
  ref.invalidate(ownedCirclesProvider);
  ref.invalidate(circleDiscoveryProvider);
}
