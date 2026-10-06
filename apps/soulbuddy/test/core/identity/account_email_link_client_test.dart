import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/identity/account_email_link_client.dart';

void main() {
  test(
    'requests a normalized email challenge with the installation session',
    () async {
      late http.Request captured;
      final client = AccountEmailLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com/'),
        accessToken: () async => 'installation-token',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'challenge_id': '2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f',
              'expires_at': '2026-10-03T07:10:00Z',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final challenge = await client.request(' Beloved@Example.com ');

      expect(captured.url.path, '/api/account/email/challenges');
      expect(captured.headers['authorization'], 'Bearer installation-token');
      expect(jsonDecode(captured.body), {'email': 'beloved@example.com'});
      expect(challenge.id, '2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f');
      expect(challenge.expiresAt, DateTime.parse('2026-10-03T07:10:00Z'));
    },
  );

  test('does not make a request without an installation session', () async {
    var called = false;
    final client = AccountEmailLinkClient(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => null,
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('', 500);
      }),
    );

    await expectLater(client.request('beloved@example.com'), throwsStateError);
    expect(called, isFalse);
  });

  test('does not make a request when the API is not configured', () async {
    var called = false;
    final client = AccountEmailLinkClient(
      apiBaseUri: Uri(),
      accessToken: () async => 'installation-token',
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('', 500);
      }),
    );

    await expectLater(client.request('beloved@example.com'), throwsStateError);
    expect(called, isFalse);
  });
}
