import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'local_identity.dart';

const localOwnerIdStorageKey = 'soulbuddy.local_owner_id';
const deviceIdStorageKey = 'soulbuddy.device_id';
const appSessionTokenStorageKey = 'soulbuddy.app_session_token';

typedef AppSessionTokenReader = Future<String?> Function();

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final localIdentityProvider = FutureProvider<LocalIdentity>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  const uuid = Uuid();

  var ownerId = await storage.read(key: localOwnerIdStorageKey);
  if (ownerId == null) {
    ownerId = uuid.v7();
    await storage.write(key: localOwnerIdStorageKey, value: ownerId);
  }

  var deviceId = await storage.read(key: deviceIdStorageKey);
  if (deviceId == null) {
    deviceId = uuid.v7();
    await storage.write(key: deviceIdStorageKey, value: deviceId);
  }

  return LocalIdentity(ownerId: ownerId, deviceId: deviceId);
});

final appSessionTokenReaderProvider = Provider<AppSessionTokenReader>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return () => storage.read(key: appSessionTokenStorageKey);
});
