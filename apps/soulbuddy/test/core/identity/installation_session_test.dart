import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/identity/installation_session.dart';
import 'package:soulbuddy/core/identity/local_identity.dart';

void main() {
  test(
    'bootstraps and stores one installation-bound application session',
    () async {
      final writes = <String, String>{};
      final requests = <http.Request>[];
      final bootstrap = InstallationSessionBootstrap(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        read: (key) async => null,
        write: (key, value) async => writes[key] = value,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'token': 'plain-session-token',
              'owner_id': 'owner-1',
              'display_name': 'SoulBuddy 4827',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await bootstrap.ensure(
        const LocalIdentity(ownerId: 'owner-1', deviceId: 'device-1'),
      );

      expect(requests, hasLength(1));
      final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(payload['owner_id'], 'owner-1');
      expect(payload['device_id'], 'device-1');
      expect((payload['installation_secret'] as String).length, 64);
      expect(
        writes[installationSecretStorageKey],
        payload['installation_secret'],
      );
      expect(writes[appSessionTokenStorageKey], 'plain-session-token');
      expect(writes[profileDisplayNameStorageKey], 'SoulBuddy 4827');
    },
  );

  test('does nothing when the API is not configured', () async {
    var calls = 0;
    final bootstrap = InstallationSessionBootstrap(
      apiBaseUri: null,
      read: (key) async => null,
      write: (key, value) async {},
      client: MockClient((request) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    await bootstrap.ensure(
      const LocalIdentity(ownerId: 'owner-1', deviceId: 'device-1'),
    );
    expect(calls, 0);
  });

  test(
    'network failure never prevents the local-first app from opening',
    () async {
      final writes = <String, String>{};
      final bootstrap = InstallationSessionBootstrap(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        read: (key) async => null,
        write: (key, value) async => writes[key] = value,
        client: MockClient((request) async {
          throw http.ClientException('offline', request.url);
        }),
      );

      await expectLater(
        bootstrap.ensure(
          const LocalIdentity(ownerId: 'owner-1', deviceId: 'device-1'),
        ),
        completes,
      );

      expect(writes[installationSecretStorageKey], hasLength(64));
      expect(writes, isNot(contains(appSessionTokenStorageKey)));
    },
  );

  test('bounds a server that accepts but never answers', () async {
    final bootstrap = InstallationSessionBootstrap(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      read: (key) async => null,
      write: (key, value) async {},
      requestTimeout: const Duration(milliseconds: 10),
      client: MockClient((request) => Completer<http.Response>().future),
    );

    await expectLater(
      bootstrap.ensure(
        const LocalIdentity(ownerId: 'owner-1', deviceId: 'device-1'),
      ),
      completes,
    );
  });
}
