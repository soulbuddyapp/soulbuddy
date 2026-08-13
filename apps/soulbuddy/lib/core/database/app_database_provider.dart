import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../identity/local_identity_providers.dart';
import '../sync/laravel_backend_connector.dart';
import 'app_database.dart';

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final String databasePath;
  if (kIsWeb) {
    databasePath = 'soulbuddy.db';
  } else {
    final applicationDirectory = await getApplicationSupportDirectory();
    databasePath = path_helper.join(applicationDirectory.path, 'soulbuddy.db');
  }

  LaravelBackendConnector? connector;
  if (AppConfig.syncConfigured) {
    await ref.watch(installationSessionBootstrapProvider.future);
    final apiBaseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (apiBaseUri != null && apiBaseUri.hasScheme) {
      final storage = ref.watch(secureStorageProvider);
      final identity = await ref.watch(localIdentityProvider.future);
      final client = http.Client();
      ref.onDispose(client.close);
      connector = LaravelBackendConnector(
        apiBaseUri: apiBaseUri,
        powerSyncEndpoint: AppConfig.powerSyncUrl,
        installationId: identity.deviceId,
        accessToken: () => storage.read(key: appSessionTokenStorageKey),
        client: client,
      );
    }
  }

  final database = await AppDatabase.open(
    path: databasePath,
    connector: connector,
  );
  ref.onDispose(() => unawaited(database.close()));
  return database;
});
