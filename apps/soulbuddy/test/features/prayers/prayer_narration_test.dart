import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/prayers/application/prayer_narration_playback_policy.dart';
import 'package:soulbuddy/features/prayers/data/laravel_prayer_narration_repository.dart';

void main() {
  test(
    'prepares exact revision narration and downloads authenticated bytes',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'status': 'ready',
              'revision_id': 'revision-1',
              'content_type': 'audio/mpeg',
              'playback_url':
                  '/api/prayer-narrations/revision-1/hash?expires=1&signature=x',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(
          [1, 2, 3, 4],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      });
      final repository = LaravelPrayerNarrationRepository(
        apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
        accessToken: () async => 'session-token',
        client: client,
      );

      final narration = await repository.prepare(
        personalPrayerId: 'prayer-1',
        prayerRevisionId: 'revision-1',
        consent: true,
      );

      expect(narration.revisionId, 'revision-1');
      expect(narration.bytes, [1, 2, 3, 4]);
      expect(requests, hasLength(2));
      expect(
        requests.first.body,
        contains('"prayer_revision_id":"revision-1"'),
      );
      expect(requests.first.body, isNot(contains('prayer text')));
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer session-token',
        ),
        isTrue,
      );
    },
  );

  test('rejects mismatched revision and unsafe audio responses', () async {
    final repository = LaravelPrayerNarrationRepository(
      apiBaseUri: Uri.parse('https://sbuddy.elbiblio.com'),
      accessToken: () async => 'token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'ready',
            'revision_id': 'wrong-revision',
            'content_type': 'audio/mpeg',
            'playback_url': '/audio',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      repository.prepare(
        personalPrayerId: 'prayer-1',
        prayerRevisionId: 'revision-1',
        consent: true,
      ),
      throwsA(isA<PrayerNarrationException>()),
    );
  });

  group('autoplay policy', () {
    const policy = PrayerNarrationPlaybackPolicy();

    test('permits once only after explicit open with a ready safe route', () {
      expect(
        policy.decide(
          explicitInAppOpen: true,
          autoplayEnabled: true,
          narrationReady: true,
          audioRoute: PrayerAudioRoute.speaker,
          interruptionsAllowed: true,
          alreadyAttempted: false,
        ),
        PrayerNarrationPlaybackDecision.autoplay,
      );
    });

    test('uses manual playback for unsafe or uncertain conditions', () {
      for (final route in PrayerAudioRoute.values) {
        if (route == PrayerAudioRoute.speaker ||
            route == PrayerAudioRoute.headphones) {
          continue;
        }
        expect(
          policy.decide(
            explicitInAppOpen: true,
            autoplayEnabled: true,
            narrationReady: true,
            audioRoute: route,
            interruptionsAllowed: true,
            alreadyAttempted: false,
          ),
          PrayerNarrationPlaybackDecision.manual,
        );
      }
      expect(
        policy.decide(
          explicitInAppOpen: false,
          autoplayEnabled: true,
          narrationReady: true,
          audioRoute: PrayerAudioRoute.speaker,
          interruptionsAllowed: true,
          alreadyAttempted: false,
        ),
        PrayerNarrationPlaybackDecision.manual,
      );
      expect(
        policy.decide(
          explicitInAppOpen: true,
          autoplayEnabled: true,
          narrationReady: true,
          audioRoute: PrayerAudioRoute.speaker,
          interruptionsAllowed: false,
          alreadyAttempted: false,
        ),
        PrayerNarrationPlaybackDecision.manual,
      );
    });
  });
}
