import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/core/identity/telegram_link_client.dart';

void main() {
  test('creates a Telegram link code with the device session', () async {
    late http.Request captured;
    final client = TelegramLinkClient(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => 'installation-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': '2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f',
            'code': 'mIrNaIk4AmQRQ70OF1qfMjD0ciU3pn8OQoYuCOakfd0',
            'expires_at': '2026-10-03T07:10:00Z',
            'start_url': 'https://t.me/SoulBuddyBot?start=code',
          }),
          202,
        );
      }),
    );

    final link = await client.createLink();

    expect(captured.url.path, '/api/companions/telegram/link-codes');
    expect(captured.headers['authorization'], 'Bearer installation-token');
    expect(link.startUrl, Uri.parse('https://t.me/SoulBuddyBot?start=code'));
  });

  test('reads a Telegram link state with the installation session', () async {
    late http.Request captured;
    final client = TelegramLinkClient(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => 'installation-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': '2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f',
            'status': 'connected',
            'expires_at': '2026-10-03T07:10:00Z',
          }),
          200,
        );
      }),
    );

    final state = await client.status('2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f');

    expect(
      captured.url.path,
      '/api/companions/telegram/link-codes/2d1b2ca3-7f06-49f9-b1f4-488a8f66d32f',
    );
    expect(captured.headers['authorization'], 'Bearer installation-token');
    expect(state, TelegramLinkState.connected);
  });
}
