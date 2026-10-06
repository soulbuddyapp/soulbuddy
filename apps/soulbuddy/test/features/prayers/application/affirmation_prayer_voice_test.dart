import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soulbuddy/features/prayers/application/affirmation_prayer_audio.dart';
import 'package:soulbuddy/features/prayers/application/affirmation_prayer_session_controller.dart';
import 'package:soulbuddy/features/prayers/data/prayer_release_narration_repository.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';

import '../../../helpers/prayer_release_fixtures.dart';
import '../application/affirmation_prayer_session_controller_test.dart'
    show FakeScreenAwake, FakeSoundBed, RecordingSessions, buildProfile;

const itemHash =
    'cf00f39b28e2cb4dd06b5b9611b3f383818646d74da62297a0749569dd6430d3';

/// Records what the voice and bed players asked the platform to do.
///
/// It implements rather than extends the player, because constructing a real one
/// would call the platform before any test can substitute it.
class _FakeAudioPlayer implements AudioPlayer {
  final played = <Object?>[];
  final volumes = <double>[];
  final rates = <double>[];
  var stops = 0;
  var requestedReleaseMode = ReleaseMode.stop;

  @override
  ReleaseMode get releaseMode => requestedReleaseMode;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add(source);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    requestedReleaseMode = releaseMode;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PrayerReleaseNarrationRepository repositoryServing(
  http.Response Function(http.Request request) handler,
) {
  return LaravelPrayerReleaseNarrationRepository(
    apiBaseUri: Uri.parse('https://api.example.test'),
    accessToken: () async => 'session-token',
    httpClient: MockClient((request) async => handler(request)),
  );
}

http.Response jsonBody(Object payload, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  // The audio players talk to platform channels, which need a test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the narration repository', () {
    test('serves validated audio for an added item', () async {
      final repository = repositoryServing(
        (request) => jsonBody({
          'status': 'ready',
          'content_sha256': itemHash,
          'narration_uri': 'prayer-releases/new-adam.mp3',
          'default_speed': 0.85,
          'available_speeds': [0.7, 0.85, 1, 1.15],
        }, 200),
      );

      final narration = await repository.load('release-item-3');

      expect(narration, isNotNull);
      expect(narration!.contentSha256, itemHash);
      expect(narration.narrationUri, 'prayer-releases/new-adam.mp3');
    });

    test(
      'returns no audio when the server serves the exact text instead',
      () async {
        final repository = repositoryServing(
          (request) => jsonBody({
            'status': 'text_only',
            'content_sha256': itemHash,
            'text': repetitionsBody,
            'default_speed': 0.85,
          }, 200),
        );

        expect(await repository.load('release-item-3'), isNull);
      },
    );

    test('refuses an item whose collection was never added', () async {
      final repository = repositoryServing(
        (request) => jsonBody({'code': 'release_not_added'}, 404),
      );

      expect(
        () => repository.load('release-item-3'),
        throwsA(
          isA<PrayerReleaseNarrationException>().having(
            (error) => error.code,
            'code',
            'release_not_added',
          ),
        ),
      );
    });

    test('refuses content whose transcript no longer matches', () async {
      final repository = repositoryServing(
        (request) => jsonBody({'code': 'narration_content_mismatch'}, 503),
      );

      expect(
        () => repository.load('release-item-3'),
        throwsA(
          isA<PrayerReleaseNarrationException>().having(
            (error) => error.code,
            'code',
            'narration_unavailable',
          ),
        ),
      );
    });

    test('offers only the approved paces with 0.85x first', () {
      expect(PrayerReleaseNarrationRepository.defaultSpeed, 0.85);
      expect(PrayerReleaseNarrationRepository.availableSpeeds, [
        0.7,
        0.85,
        1.0,
        1.15,
      ]);
    });

    test('fetches audio bytes with the account session', () async {
      late http.Request seen;
      final repository = repositoryServing((request) {
        seen = request;

        return http.Response.bytes([1, 2, 3], 200);
      });

      final bytes = await repository.bytes(
        const PrayerReleaseNarration(
          contentSha256: itemHash,
          narrationUri: 'prayer-releases/new-adam.mp3',
        ),
      );

      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(
        seen.url.path,
        '/api/prayer-release-narration/prayer-releases/new-adam.mp3',
      );
      expect(seen.headers['authorization'], 'Bearer session-token');
    });
  });

  group('the voice seam', () {
    test('replays validated audio without changing any count', () async {
      var spoken = 0;
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      late final AffirmationPrayerVoice voice;
      voice = AffirmationPrayerVoice(
        speakPhrase: (phrase, speed) async {
          spoken++;
          await voice.playAsset(Uint8List.fromList([1, 2, 3]), speed: speed);
        },
        player: audio,
      );
      addTearDown(voice.dispose);

      final controller = AffirmationPrayerSessionController(
        profile: buildProfile(),
        releaseItemId: 'release-item-3',
        sessionId: 'session-1',
        narration: voice,
        soundBed: FakeSoundBed(),
        awake: FakeScreenAwake(),
        saveSession: RecordingSessions.new,
        now: () => DateTime.utc(2026, 10, 6, 9),
      );
      addTearDown(controller.dispose);

      await controller.begin();
      // The deliberate begin reads the phrase once.
      expect(spoken, 1);
      expect(audio.played, hasLength(1));
      expect(audio.rates, contains(0.85));

      await controller.hearAgain();

      // Replaying reads it again, at the approved pace, and advances nothing.
      expect(spoken, 2);
      expect(audio.played, hasLength(2));
      expect(controller.state.stepOneCount, 0);

      await controller.confirmSpoken();
      expect(controller.state.stepOneCount, 1);

      await controller.hearAgain();
      expect(spoken, 3);
      expect(controller.state.stepOneCount, 1);
    });

    test(
      'refuses an implausibly large asset rather than buffering it',
      () async {
        final audio = _FakeAudioPlayer();
        addTearDown(audio.dispose);
        final voice = AffirmationPrayerVoice(
          speakPhrase: (phrase, speed) async {},
          player: audio,
          downloadBudgetBytes: 4,
        );
        addTearDown(voice.dispose);

        await voice.playAsset(Uint8List.fromList([1, 2, 3, 4, 5]), speed: .85);

        expect(audio.played, isEmpty);
        await voice.stop();
      },
    );

    test('stops immediately and ignores a late load', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final voice = AffirmationPrayerVoice(
        speakPhrase: (phrase, speed) async {},
        player: audio,
      );
      addTearDown(voice.dispose);

      await voice.playAsset(Uint8List.fromList([1, 2, 3]), speed: .7);
      expect(audio.played, hasLength(1));

      await voice.stop();
      expect(audio.stops, greaterThanOrEqualTo(2));
    });
  });

  group('the bed player', () {
    test('starts a bed low and loops it', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final bed = AffirmationPrayerBedPlayer(player: audio);
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'oceanWaves', volume: .2);

      expect(audio.played, hasLength(1));
      expect(audio.requestedReleaseMode, ReleaseMode.loop);
      // A bed stays low enough for spoken prayer.
      expect(audio.volumes.last, lessThanOrEqualTo(.3));
    });

    test('lowers a chosen bed for a pause instead of silencing it', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final bed = AffirmationPrayerBedPlayer(player: audio);
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'gentleRain', volume: .2);
      await bed.duck();

      expect(audio.played, hasLength(1), reason: 'the bed keeps playing');
      expect(audio.volumes.last, lessThan(.2));

      await bed.restore();
      expect(audio.volumes.last, closeTo(.2, .001));
    });

    test('ignores an unknown sound key', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final bed = AffirmationPrayerBedPlayer(player: audio);
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'not_a_real_bed', volume: .2);

      expect(audio.played, isEmpty);
    });
  });

  group('the cached profile', () {
    test('speaks phrases that rebuild the exact source lines', () {
      final item = releaseContentFixture().firstWhere(
        (candidate) => candidate.libraryPrayerId == 'release-prayer-3',
      );
      final profile = AffirmationPrayerProfile.fromPractice(item.practice!);

      expect(profile.stepOneSourceLine, endsWith('(x50)'));
      expect(profile.stepTwoSourceLine, endsWith('(x10)'));
      expect(
        profile.stepOnePhrase,
        profile.stepOneSourceLine.replaceFirst(' (x50)', ''),
      );
      expect(
        profile.stepTwoPhrase,
        profile.stepTwoSourceLine.replaceFirst(' (x10)', ''),
      );
    });
  });
}
