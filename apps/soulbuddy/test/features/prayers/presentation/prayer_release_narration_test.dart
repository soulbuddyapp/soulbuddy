import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/prayers/data/prayer_release_api_client.dart';

import '../../../helpers/prayer_release_fixtures.dart';

/// Mirrors the server's narration contract for a release item.
class ReleaseItemNarrationClient {
  ReleaseItemNarrationClient({required this.httpClient})
    : client = PrayerReleaseApiClient(
        apiBaseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'session-token',
        httpClient: httpClient,
      );

  final http.Client httpClient;
  final PrayerReleaseApiClient client;

  Future<Map<String, dynamic>> fetch(String itemId) async {
    final response = await httpClient.get(
      Uri.parse('https://api.example.test/api/prayer-release-items/$itemId/narration'),
      headers: {
        'accept': 'application/json',
        'authorization': 'Bearer session-token',
      },
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

http.Response jsonBody(Object payload, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  const itemId = 'release-item-3';

  test('serves the exact visible text with the 0.85x default when no asset matches', () async {
    late Uri requested;
    final client = ReleaseItemNarrationClient(
      httpClient: MockClient((request) async {
        requested = request.url;

        return jsonBody({
          'status': 'text_only',
          'default_speed': 0.85,
          'available_speeds': [0.7, 0.85, 1, 1.15],
          'content_sha256': 'cf00f39b28e2cb4dd06b5b9611b3f383818646d74da62297a0749569dd6430d3',
          'text': repetitionsBody,
        }, 200);
      }),
    );

    final payload = await client.fetch(itemId);

    expect(requested.path, '/api/prayer-release-items/$itemId/narration');
    expect(payload['status'], 'text_only');
    expect(payload['default_speed'], 0.85);
    expect(payload['available_speeds'], [0.7, 0.85, 1, 1.15]);
    expect(payload['text'], repetitionsBody);
    expect(payload['text'], contains('(x50)'));
    expect(payload['text'], contains('rebuked o Lord (x10)'));
  });

  test('offers the asset only when its transcript hash matches', () async {
    final client = ReleaseItemNarrationClient(
      httpClient: MockClient(
        (_) async => jsonBody({
          'status': 'ready',
          'default_speed': 0.85,
          'available_speeds': [0.7, 0.85, 1, 1.15],
          'content_sha256':
              'cf00f39b28e2cb4dd06b5b9611b3f383818646d74da62297a0749569dd6430d3',
          'narration_uri': 'prayer-releases/new-adam.mp3',
        }, 200),
      ),
    );

    final payload = await client.fetch(itemId);

    expect(payload['status'], 'ready');
    expect(payload['narration_uri'], 'prayer-releases/new-adam.mp3');
  });

  test('refuses a transcript that is not this exact content', () async {
    final client = ReleaseItemNarrationClient(
      httpClient: MockClient(
        (_) async => jsonBody({'code': 'narration_content_mismatch'}, 503),
      ),
    );

    final response = await client.httpClient.get(
      Uri.parse('https://api.example.test/api/prayer-release-items/$itemId/narration'),
    );

    expect(response.statusCode, 503);
    expect(
      (jsonDecode(response.body) as Map<String, dynamic>)['code'],
      'narration_content_mismatch',
    );
  });

  test('refuses narration for a collection that was not added', () async {
    final client = ReleaseItemNarrationClient(
      httpClient: MockClient(
        (_) async => jsonBody({'code': 'release_not_added'}, 404),
      ),
    );

    final response = await client.httpClient.get(
      Uri.parse('https://api.example.test/api/prayer-release-items/$itemId/narration'),
    );

    expect(response.statusCode, 404);
    expect(
      (jsonDecode(response.body) as Map<String, dynamic>)['code'],
      'release_not_added',
    );
  });

  test('ships no placeholder voice content in the release artifact', () {
    // The client must never synthesize wording the source does not contain.
    final item = releaseContentFixture().firstWhere(
      (candidate) => candidate.libraryPrayerId == 'release-prayer-3',
    );

    expect(item.practice?.steps.map((step) => step.sourceLine), [
      'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)',
      'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)',
    ]);
    expect(
      item.practice!.steps.map((step) => step.rebuildsSourceLine()),
      everyElement(isTrue),
    );
    expect(item.action, isNull);
  });
}
