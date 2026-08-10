import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../data/encounter_repository.dart';
import '../data/powersync_encounter_repository.dart';
import '../domain/encounter.dart';

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final _localIdentityProvider = FutureProvider<_LocalIdentity>((ref) async {
  final storage = ref.watch(_secureStorageProvider);
  const uuid = Uuid();

  var ownerId = await storage.read(key: 'soulbuddy.local_owner_id');
  if (ownerId == null) {
    ownerId = uuid.v7();
    await storage.write(key: 'soulbuddy.local_owner_id', value: ownerId);
  }

  var deviceId = await storage.read(key: 'soulbuddy.device_id');
  if (deviceId == null) {
    deviceId = uuid.v7();
    await storage.write(key: 'soulbuddy.device_id', value: deviceId);
  }

  return _LocalIdentity(ownerId: ownerId, deviceId: deviceId);
});

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final String databasePath;
  if (kIsWeb) {
    databasePath = 'soulbuddy.db';
  } else {
    final applicationDirectory = await getApplicationSupportDirectory();
    databasePath = path_helper.join(applicationDirectory.path, 'soulbuddy.db');
  }

  final database = await AppDatabase.open(path: databasePath);
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final encounterRepositoryProvider = FutureProvider<EncounterRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(_localIdentityProvider.future);

  return PowerSyncEncounterRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
    deviceId: identity.deviceId,
  );
});

final encountersProvider = StreamProvider<List<Encounter>>((ref) async* {
  final repository = await ref.watch(encounterRepositoryProvider.future);
  yield* repository.watchAll();
});

class _LocalIdentity {
  const _LocalIdentity({required this.ownerId, required this.deviceId});

  final String ownerId;
  final String deviceId;
}
