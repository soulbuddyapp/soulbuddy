import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../identity/local_identity_providers.dart';
import '../sync/laravel_backend_connector.dart';
import '../sync/saved_records_upload_pump.dart';
import 'app_database.dart';

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final missing = AppConfig.missingConfiguration();
  if (missing.isNotEmpty && kDebugMode) {
    debugPrint(
      'SoulBuddy is missing ${missing.join(' and ')}. Saved records will stay '
      'on this device and nothing will be recorded.',
    );
  }

  final String databasePath;
  if (kIsWeb) {
    databasePath = 'soulbuddy.db';
  } else {
    final applicationDirectory = await getApplicationSupportDirectory();
    databasePath = path_helper.join(applicationDirectory.path, 'soulbuddy.db');
  }

  final connector = await _buildBackendConnector(ref);
  final mode = resolveSyncMode(
    uploadConfigured: connector != null,
    downloadConfigured: AppConfig.downloadConfigured,
  );

  if (mode == SyncMode.download && connector != null) {
    // A sync service is reachable, so PowerSync runs both directions itself.
    final database = await AppDatabase.open(
      path: databasePath,
      connector: connector,
    );
    ref.onDispose(() => unawaited(database.close()));
    return database;
  }

  final database = await AppDatabase.open(path: databasePath);
  ref.onDispose(() => unawaited(database.close()));

  if (mode == SyncMode.uploadOnly && connector != null) {
    // Reads stay unavailable without a sync service. Saved records still
    // reach Laravel on their own, and gating that on the service is what
    // stranded every prayer written on a build without one.
    final pump = SavedRecordsUploadPump(
      database: database.powersync,
      connector: connector,
    )..start();
    ref.onDispose(() => unawaited(pump.stop()));
  }

  return database;
});

/// The connector for the Laravel boundary, or null when this build has no
/// boundary to talk to.
Future<LaravelBackendConnector?> _buildBackendConnector(Ref ref) async {
  if (!AppConfig.uploadConfigured) return null;

  await ref.watch(installationSessionBootstrapProvider.future);
  final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiBaseUri == null || !apiBaseUri.hasScheme) return null;

  final storage = ref.watch(secureStorageProvider);
  final identity = await ref.watch(localIdentityProvider.future);
  final client = http.Client();
  ref.onDispose(client.close);

  return LaravelBackendConnector(
    apiBaseUri: apiBaseUri,
    powerSyncEndpoint: AppConfig.powerSyncUrl,
    installationId: identity.deviceId,
    accessToken: () => storage.read(key: appSessionTokenStorageKey),
    client: client,
  );
}
