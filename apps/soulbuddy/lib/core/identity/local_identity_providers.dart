import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import 'account_email_link_client.dart';
import 'installation_session.dart';
import 'local_identity.dart';

const localOwnerIdStorageKey = 'soulbuddy.local_owner_id';
const deviceIdStorageKey = 'soulbuddy.device_id';
const appSessionTokenStorageKey = 'soulbuddy.app_session_token';
const profileDisplayNameStorageKey = 'soulbuddy.profile_display_name';

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

final accountEmailLinkClientProvider = Provider<AccountEmailLinkClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AccountEmailLinkClient(
    apiBaseUri: Uri.tryParse(AppConfig.apiBaseUrl) ?? Uri(),
    accessToken: ref.watch(appSessionTokenReaderProvider),
    httpClient: client,
  );
});

final installationSessionBootstrapProvider = FutureProvider<void>((ref) async {
  final configured = Uri.tryParse(AppConfig.apiBaseUrl);
  if (configured == null || !configured.hasScheme) return;
  final storage = ref.watch(secureStorageProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  final bootstrap = InstallationSessionBootstrap(
    apiBaseUri: configured,
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
    client: client,
  );
  await bootstrap.ensure(await ref.watch(localIdentityProvider.future));
});
