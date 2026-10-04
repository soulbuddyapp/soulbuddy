import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/daily_formation/data/formation_activity_client.dart';

void main() {
  test('records an opened formation video with the device session', () async {
    late http.Request captured;
    final client = FormationActivityClient(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => 'installation-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'recorded': true}), 201);
      }),
    );

    final recorded = await client.recordOpened('formation-video-1');

    expect(recorded, isTrue);
    expect(captured.url.path, '/api/formation/activity');
    expect(captured.headers['authorization'], 'Bearer installation-token');
    expect(jsonDecode(captured.body), {
      'formation_video_id': 'formation-video-1',
      'activity_type': 'opened',
    });
  });
}
