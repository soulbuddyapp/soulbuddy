import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/circles/data/circle_directory_repository.dart';
import 'package:soulbuddy/features/circles/data/laravel_circle_directory_repository.dart';
import 'package:soulbuddy/features/circles/domain/circle.dart';

void main() {
  test('discovers typed Circles with bearer auth and cursor filters', () async {
    late http.Request captured;
    final repository = LaravelCircleDirectoryRepository(
      apiBaseUri: Uri.parse('https://sbuddy.example'),
      tokenReader: () async => 'session-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': [_circleJson()],
            'next_cursor': 'next-page',
          }),
          200,
        );
      }),
    );

    final page = await repository.discover(
      const CircleDiscoveryQuery(
        category: CircleCategory.accountability,
        search: 'walk',
        cursor: 'cursor-1',
        limit: 12,
      ),
    );

    expect(captured.headers['authorization'], 'Bearer session-token');
    expect(captured.url.path, '/api/circles');
    expect(captured.url.queryParameters['category'], 'accountability');
    expect(captured.url.queryParameters['q'], 'walk');
    expect(captured.url.queryParameters['cursor'], 'cursor-1');
    expect(captured.url.queryParameters['limit'], '12');
    expect(page.items.single.name, 'Walk together');
    expect(page.items.single.provider, CircleProvider.telegram);
    expect(page.items.single.directoryListed, isTrue);
    expect(page.nextCursor, 'next-page');
  });

  test('create sends metadata only and never a chat message payload', () async {
    Map<String, dynamic>? payload;
    final repository = LaravelCircleDirectoryRepository(
      apiBaseUri: Uri.parse('https://sbuddy.example'),
      tokenReader: () async => 'session-token',
      client: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_circleJson()), 201);
      }),
    );

    await repository.create(
      CircleDraft(
        name: 'Walk together',
        category: CircleCategory.accountability,
        description: 'Honest accountability and prayer.',
        visibility: CircleVisibility.public,
        provider: CircleProvider.telegram,
        openUri: Uri.parse('https://t.me/+soulbuddy-test'),
      ),
    );

    expect(payload?.keys.toSet(), {
      'name',
      'category',
      'description',
      'visibility',
      'provider',
      'open_url',
    });
    expect(payload, isNot(contains('message')));
    expect(payload, isNot(contains('body')));
  });

  test(
    'missing session and forbidden records fail without exposing response bodies',
    () async {
      final noSession = LaravelCircleDirectoryRepository(
        apiBaseUri: Uri.parse('https://sbuddy.example'),
        tokenReader: () async => null,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        noSession.discover(const CircleDiscoveryQuery()),
        throwsA(isA<CircleDirectoryUnavailable>()),
      );

      final forbidden = LaravelCircleDirectoryRepository(
        apiBaseUri: Uri.parse('https://sbuddy.example'),
        tokenReader: () async => 'token',
        client: MockClient((_) async => http.Response('private text', 403)),
      );
      await expectLater(
        forbidden.get('circle-1'),
        throwsA(isA<CircleDirectoryForbidden>()),
      );
    },
  );

  test('rejects hostile or provider-mismatched handoff URLs from the API', () async {
    for (final unsafeUrl in [
      'https://example.com/not-telegram',
      'https://chat.whatsapp.com/not-telegram',
      'https://user:pass@t.me/+credentialed',
      'https://t.me:8443/+wrong-port',
      'http://t.me/+not-https',
      'https://t.me/',
    ]) {
      final repository = LaravelCircleDirectoryRepository(
        apiBaseUri: Uri.parse('https://sbuddy.example'),
        tokenReader: () async => 'session-token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(_circleJson(openUrl: unsafeUrl)),
            200,
          ),
        ),
      );

      await expectLater(
        repository.get('circle-1'),
        throwsA(isA<CircleDirectoryUnavailable>()),
        reason: unsafeUrl,
      );
    }
  });

  test('accepts only the matching provider host family', () {
    expect(
      CircleProvider.telegram.allows(Uri.parse('https://t.me/+group')),
      isTrue,
    );
    expect(
      CircleProvider.telegram.allows(
        Uri.parse('https://chat.whatsapp.com/group'),
      ),
      isFalse,
    );
    expect(
      CircleProvider.whatsappLink.allows(
        Uri.parse('https://chat.whatsapp.com/group'),
      ),
      isTrue,
    );
    expect(
      CircleProvider.whatsappLink.allows(Uri.parse('https://wa.me/2348012345678')),
      isTrue,
    );
  });
}

Map<String, dynamic> _circleJson({String? openUrl}) => {
  'public_id': '0198b100-0000-7000-8000-000000000001',
  'name': 'Walk together',
  'category': 'accountability',
  'description': 'Honest accountability and prayer.',
  'visibility': 'public',
  'status': 'active',
  'directory_listed': true,
  'provider': 'telegram',
  'open_url': openUrl ?? 'https://t.me/+soulbuddy-test',
  'capabilities': ['open_link'],
  'member_count': null,
  'is_owner': false,
  'updated_at': '2026-08-29T12:00:00.000Z',
};
