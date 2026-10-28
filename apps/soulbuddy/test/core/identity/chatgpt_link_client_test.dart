import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/identity/chatgpt_link_client.dart';

void main() {
  test(
    'uses the current SoulBuddy installation session for owner-scoped status',
    () async {
      late http.Request captured;
      final client = ChatgptLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com/sb-stage'),
        accessToken: () async => 'device-session',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'linked': true}), 200);
        }),
      );

      expect(await client.status(), isTrue);
      expect(captured.method, 'GET');
      expect(captured.url.path, '/sb-stage/api/account/chatgpt/status');
      expect(captured.headers['authorization'], 'Bearer device-session');
      expect(captured.followRedirects, isFalse);
    },
  );

  test(
    'requests a one-use link code without logging or persisting it',
    () async {
      late http.Request captured;
      final client = ChatgptLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        accessToken: () async => 'device-session',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'code': 'abcdef0123456789abcdef0123456789',
              'expires_at': '2099-01-01T12:00:00Z',
            }),
            201,
          );
        }),
      );

      final result = await client.createCode();
      expect(captured.url.path, '/api/account/chatgpt/link-codes');
      expect(captured.method, 'POST');
      expect(captured.headers['authorization'], 'Bearer device-session');
      expect(captured.followRedirects, isFalse);
      expect(jsonDecode(captured.body), {'confirmed': true});
      expect(result.code, 'abcdef0123456789abcdef0123456789');
      expect(result.expiresAt, DateTime.utc(2099, 1, 1, 12));
    },
  );

  test(
    'explicitly unlinks the local user without claiming provider revocation',
    () async {
      late http.Request captured;
      final client = ChatgptLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        accessToken: () async => 'device-session',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'unlinked': true}), 200);
        }),
      );

      expect(await client.unlink(), isTrue);
      expect(captured.url.path, '/api/account/chatgpt/unlink');
      expect(jsonDecode(captured.body), {'confirmed': true});
      expect(captured.followRedirects, isFalse);
    },
  );

  test(
    'does not contact an insecure nonlocal server or a missing session',
    () async {
      var requests = 0;
      Future<http.Response> handler(http.Request request) async {
        requests++;
        return http.Response('{}', 200);
      }

      final insecure = ChatgptLinkClient(
        apiBaseUri: Uri.parse('http://sbuddy.example'),
        accessToken: () async => 'token',
        httpClient: MockClient(handler),
      );
      await expectLater(insecure.status(), throwsStateError);
      final unsigned = ChatgptLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        accessToken: () async => null,
        httpClient: MockClient(handler),
      );
      await expectLater(unsigned.createCode(), throwsStateError);
      expect(requests, 0);
    },
  );

  test('fails closed on redirects and malformed response bodies', () async {
    var calls = 0;
    final client = ChatgptLinkClient(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => 'device-session',
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.example/steal'},
          );
        }
        return http.Response(jsonEncode({'linked': 'yes'}), 200);
      }),
    );

    await expectLater(client.status(), throwsA(isA<ChatgptLinkException>()));
    await expectLater(client.status(), throwsA(isA<ChatgptLinkException>()));
  });

  test(
    'requires verified email and a correctly shaped code response',
    () async {
      var calls = 0;
      final client = ChatgptLinkClient(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        accessToken: () async => 'device-session',
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(jsonEncode({'message': 'validation'}), 422);
          }
          return http.Response(
            jsonEncode({
              'code': 'not-a-valid-code',
              'expires_at': '2099-01-01T12:00:00Z',
            }),
            201,
          );
        }),
      );

      await expectLater(
        client.createCode(),
        throwsA(
          isA<ChatgptLinkException>().having(
            (e) => e.message,
            'message',
            contains('Verify your SoulBuddy email'),
          ),
        ),
      );
      await expectLater(
        client.createCode(),
        throwsA(isA<ChatgptLinkException>()),
      );
    },
  );
}
