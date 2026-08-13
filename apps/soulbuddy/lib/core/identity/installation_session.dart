import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'local_identity.dart';
import 'local_identity_providers.dart' show appSessionTokenStorageKey;
import 'local_identity_providers.dart' show profileDisplayNameStorageKey;

export 'local_identity_providers.dart'
    show appSessionTokenStorageKey, profileDisplayNameStorageKey;

const installationSecretStorageKey = 'soulbuddy.installation_secret';

class InstallationSessionBootstrap {
  InstallationSessionBootstrap({
    required this.apiBaseUri,
    required this.read,
    required this.write,
    required this.client,
    this.requestTimeout = const Duration(seconds: 15),
  });

  final Uri? apiBaseUri;
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final http.Client client;
  final Duration requestTimeout;

  Future<void> ensure(LocalIdentity identity) async {
    final base = apiBaseUri;
    if (base == null || !base.hasScheme) return;
    var secret = await read(installationSecretStorageKey);
    if (secret == null || secret.length != 64) {
      secret = _randomSecret();
      await write(installationSecretStorageKey, secret);
    }
    try {
      final response = await client
          .post(
            Uri.parse(
              '${base.toString().replaceFirst(RegExp(r'/$'), '')}/api/installations/session',
            ),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'owner_id': identity.ownerId,
              'device_id': identity.deviceId,
              'installation_secret': secret,
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['owner_id'] != identity.ownerId ||
          decoded['token'] is! String ||
          (decoded['token'] as String).isEmpty ||
          decoded['display_name'] is! String ||
          (decoded['display_name'] as String).isEmpty) {
        return;
      }
      await write(appSessionTokenStorageKey, decoded['token'] as String);
      await write(
        profileDisplayNameStorageKey,
        decoded['display_name'] as String,
      );
    } on Exception {
      // Session refresh is best-effort. The local-first app must remain usable
      // while the API is unavailable, and the stored secret enables retry.
      return;
    }
  }

  String _randomSecret() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final random = Random.secure();
    return List.generate(
      64,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
