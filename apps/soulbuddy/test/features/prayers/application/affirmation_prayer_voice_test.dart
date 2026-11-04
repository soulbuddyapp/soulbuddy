import 'dart:async';
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
import 'package:soulbuddy/features/prayers/domain/worship_sound_bed.dart';

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
  final completions = StreamController<void>.broadcast();
  var stops = 0;
  var requestedReleaseMode = ReleaseMode.stop;

  @override
  ReleaseMode get releaseMode => requestedReleaseMode;

  @override
  Stream<void> get onPlayerComplete => completions.stream;

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
    // A real player reports finishing once its audio has run out; the guide's
    // read ends on that event, so the fake has to raise it too.
    completions.add(null);
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
  Future<void> dispose() async => completions.close();

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

    test('plays a worship arrangement instead of looping it', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final bed = AffirmationPrayerBedPlayer(player: audio);
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'tenThousandReasons', volume: .2);

      expect(audio.played, hasLength(1));
      // A whole song ends. Looping it would replay a chorus nobody asked for.
      expect(audio.requestedReleaseMode, ReleaseMode.release);
    });

    test(
      'fades a worship arrangement out at its end rather than cutting',
      () async {
        final audio = _FakeAudioPlayer();
        addTearDown(audio.dispose);
        final waits = <Duration>[];
        final bed = AffirmationPrayerBedPlayer(
          player: audio,
          fadeSteps: 4,
          fadeStep: const Duration(milliseconds: 100),
          // The wait is recorded instead of elapsed, so the fade's shape is
          // checked without waiting out a real song.
          delay: (duration) async => waits.add(duration),
        );
        addTearDown(bed.dispose);

        await bed.start(soundKey: 'tenThousandReasons', volume: .2);
        final afterStart = audio.volumes.length;
        // The fade is scheduled behind the start, so let its steps run. Every
        // wait is recorded rather than elapsed, so nothing real is waited out.
        await Future<void>.delayed(Duration.zero);

        // Four hundred milliseconds of fade, scheduled so it begins at the very
        // end of the arrangement and not a moment after it.
        expect(
          waits.first,
          WorshipSoundBed.tenThousandReasons.duration -
              const Duration(milliseconds: 400),
        );
        // Three further waits separate the four steps.
        expect(waits.skip(1), everyElement(const Duration(milliseconds: 100)));
        expect(waits, hasLength(4));

        final fade = audio.volumes.sublist(afterStart);
        expect(fade, hasLength(4));
        expect(fade, [
          closeTo(0.15, 1e-9),
          closeTo(0.10, 1e-9),
          closeTo(0.05, 1e-9),
          closeTo(0.0, 1e-9),
        ]);
        // Monotonic and never negative: the song gets quieter, it is not muted
        // partway and then brought back.
        expect(
          fade,
          orderedEquals(List.of(fade)..sort((a, b) => b.compareTo(a))),
        );
        expect(fade.every((level) => level >= 0), isTrue);
      },
    );

    test('stopping during a worship arrangement cancels its fade', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final gate = Completer<void>();
      var waits = 0;
      final bed = AffirmationPrayerBedPlayer(
        player: audio,
        fadeSteps: 6,
        fadeStep: const Duration(milliseconds: 100),
        delay: (_) async {
          waits++;
          if (waits == 1) await gate.future;
        },
      );
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'animaChristi', volume: .1);
      final beforeStop = audio.volumes.length;

      final stopping = bed.stop();
      gate.complete();
      await stopping;

      // No fade steps were applied to a bed that is no longer playing.
      expect(audio.volumes.length, beforeStop);
    });

    test('an ambient bed still loops, so its fade never runs', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final waits = <Duration>[];
      final bed = AffirmationPrayerBedPlayer(
        player: audio,
        delay: (duration) async => waits.add(duration),
      );
      addTearDown(bed.dispose);

      await bed.start(soundKey: 'oceanWaves', volume: .15);
      await Future<void>.delayed(Duration.zero);

      expect(audio.requestedReleaseMode, ReleaseMode.loop);
      expect(waits, isEmpty);
    });

    test('a guide read ends when it is stopped, not left hanging', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      late final AffirmationPrayerVoice voice;
      voice = AffirmationPrayerVoice(
        speakPhrase: (phrase, speed) async =>
            voice.playAsset(Uint8List.fromList([1, 2, 3]), speed: speed),
        player: audio,
      );
      addTearDown(voice.dispose);

      // A platform that never reports completion must not leave the bed ducked
      // for the rest of the prayer, so a stop ends the read too.
      final speaking = voice.speak('a phrase', speed: .85);
      await voice.stop();
      await speaking.timeout(const Duration(seconds: 1));
    });

    test('ducking with nothing playing leaves the level alone', () async {
      final audio = _FakeAudioPlayer();
      addTearDown(audio.dispose);
      final bed = AffirmationPrayerBedPlayer(player: audio);
      addTearDown(bed.dispose);

      // Duck used to fall back to the narration default, which is a speed.
      // With no bed playing there is no level to lower.
      await bed.duck();

      expect(audio.volumes, isEmpty);
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
