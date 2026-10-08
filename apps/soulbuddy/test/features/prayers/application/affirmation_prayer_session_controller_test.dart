import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/affirmation_prayer_session_controller.dart';
import 'package:soulbuddy/features/prayers/domain/affirmation_prayer.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_release.dart';

const stepOnePhrase =
    'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus';
const stepOneSourceLine =
    'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x50)';
const stepTwoPhrase =
    'In moments that distract me from your perfect will, let Satan be rebuked o Lord';
const stepTwoSourceLine =
    'In moments that distract me from your perfect will, let Satan be rebuked o Lord (x10)';

class FakeNarration implements AffirmationPrayerNarrationPlayer {
  final List<String> spoken = [];
  final List<String> repeated = [];
  var stopCount = 0;

  @override
  Future<void> speak(String phrase, {required double speed}) async {
    spoken.add(phrase);
  }

  @override
  Future<void> repeat(String phrase, {required double speed}) async {
    repeated.add(phrase);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  void dispose() {}
}

class FakeSoundBed implements AffirmationPrayerSoundBed {
  String? playing;
  double? volume;
  var duckCount = 0;
  var restoreCount = 0;
  var stopCount = 0;
  double? _chosen;

  @override
  Future<void> start({required String soundKey, required double volume}) async {
    playing = soundKey;
    _chosen = volume;
    this.volume = volume;
  }

  @override
  Future<void> duck() async {
    duckCount++;
    volume = (_chosen ?? .15) * .4;
  }

  @override
  Future<void> restore() async {
    restoreCount++;
    volume = _chosen ?? .15;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    playing = null;
  }

  @override
  void dispose() {}
}

/// Records the actual level asked for, so a duck can be shown to be a
/// reduction rather than a mute.
class _RecordingSoundBed implements AffirmationPrayerSoundBed {
  String? playing;
  double? volume;
  final levels = <double>[];
  var stopCount = 0;
  double? _chosen;

  @override
  Future<void> start({required String soundKey, required double volume}) async {
    playing = soundKey;
    _chosen = volume;
    volume = volume;
    levels.add(volume);
  }

  @override
  Future<void> duck() async {
    // The same arithmetic the real bed player uses: a fixed fraction of the
    // chosen level, so a duck is always a reduction and never a mute.
    final ducked = (_chosen ?? .15) * .4;
    volume = ducked;
    levels.add(ducked);
  }

  @override
  Future<void> restore() async {
    final chosen = _chosen;
    if (chosen == null) return;
    volume = chosen;
    levels.add(chosen);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    playing = null;
    _chosen = null;
  }

  @override
  void dispose() {}
}

/// A guide that keeps reading until the test releases it.
class _BlockingNarration implements AffirmationPrayerNarrationPlayer {
  final reading = Completer<void>();
  final _released = Completer<void>();
  var stopCount = 0;

  @override
  Future<void> speak(String phrase, {required double speed}) async {
    reading.complete();
    await _released.future;
  }

  @override
  Future<void> repeat(String phrase, {required double speed}) =>
      speak(phrase, speed: speed);

  @override
  Future<void> stop() async {
    stopCount++;
    release();
  }

  /// Lets a blocked read finish.
  void release() {
    if (!_released.isCompleted) _released.complete();
  }

  @override
  void dispose() {}
}

class FakeScreenAwake implements AffirmationPrayerScreenAwake {
  final List<bool> states = [];

  @override
  Future<void> setEnabled(bool value) async {
    states.add(value);
  }
}

class RecordingSessions implements AffirmationPrayerSessionRepository {
  final List<AffirmationPrayerSession> saved = [];
  var shouldFail = false;

  @override
  Future<void> save(AffirmationPrayerSession session) async {
    if (shouldFail) throw StateError('offline');
    saved.add(session);
  }
}

AffirmationPrayerProfile buildProfile() {
  return AffirmationPrayerProfile.fromPractice(
    PrayerReleasePractice(
      mode: PrayerReleasePractice.affirmationRepetition,
      steps: [
        PrayerReleasePracticeStep(
          phrase: stepOnePhrase,
          targetCount: 50,
          sourceLine: stepOneSourceLine,
        ),
        PrayerReleasePracticeStep(
          phrase: stepTwoPhrase,
          targetCount: 10,
          sourceLine: stepTwoSourceLine,
        ),
      ],
    ),
  );
}

void main() {
  late FakeNarration narration;
  late FakeSoundBed bed;
  late FakeScreenAwake awake;
  late RecordingSessions sessions;

  setUp(() {
    narration = FakeNarration();
    bed = FakeSoundBed();
    awake = FakeScreenAwake();
    sessions = RecordingSessions();
  });

  AffirmationPrayerSessionController buildController({
    AffirmationPrayerProfile? profile,
    DateTime? now,
  }) {
    return AffirmationPrayerSessionController(
      profile: profile ?? buildProfile(),
      releaseItemId: 'release-item-3',
      sessionId: 'session-1',
      narration: narration,
      soundBed: bed,
      awake: awake,
      saveSession: () => sessions,
      now: () => now ?? DateTime.utc(2026, 10, 6, 9),
    );
  }

  group('profile parsing', () {
    test('reads the two exact phrases and their source lines', () {
      final profile = buildProfile();

      expect(profile.stepOnePhrase, stepOnePhrase);
      expect(profile.stepOneSourceLine, stepOneSourceLine);
      expect(profile.stepOneTarget, 50);
      expect(profile.stepTwoPhrase, stepTwoPhrase);
      expect(profile.stepTwoSourceLine, stepTwoSourceLine);
      expect(profile.stepTwoTarget, 10);
    });

    test('rejects a profile that cannot rebuild its source line', () {
      expect(
        () => AffirmationPrayerProfile.fromPractice(
          PrayerReleasePractice(
            mode: PrayerReleasePractice.affirmationRepetition,
            steps: [
              const PrayerReleasePracticeStep(
                phrase: 'A different phrase',
                targetCount: 50,
                sourceLine: stepOneSourceLine,
              ),
              const PrayerReleasePracticeStep(
                phrase: stepTwoPhrase,
                targetCount: 10,
                sourceLine: stepTwoSourceLine,
              ),
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects targets other than fifty then ten', () {
      expect(
        () => AffirmationPrayerProfile.fromPractice(
          PrayerReleasePractice(
            mode: PrayerReleasePractice.affirmationRepetition,
            steps: [
              const PrayerReleasePracticeStep(
                phrase: stepOnePhrase,
                targetCount: 40,
                sourceLine:
                    'Dear Lord, renew my mind and heart and make me a new Adam in Christ Jesus (x40)',
              ),
              const PrayerReleasePracticeStep(
                phrase: stepTwoPhrase,
                targetCount: 10,
                sourceLine: stepTwoSourceLine,
              ),
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('recollection', () {
    test('moves through five lines and can be skipped immediately', () async {
      final controller = buildController();

      expect(controller.state.phase, AffirmationPrayerPhase.recollection);
      expect(AffirmationPrayerWords.recollectionLines, [
        'Let your body grow still',
        'Let the noise fade away',
        'Lift your heart to God',
        "Recognize God's presence and sovereignty",
        'Be still, and know that I am God',
      ]);

      for (var index = 0; index < 4; index++) {
        controller.advanceRecollection();
      }
      expect(controller.state.recollectionIndex, 4);

      controller.advanceRecollection();
      expect(controller.state.phase, AffirmationPrayerPhase.setup);
      // No narration or music has started.
      expect(narration.spoken, isEmpty);
      expect(bed.playing, isNull);

      final skipped = buildController();
      skipped.skipRecollection();
      expect(skipped.state.phase, AffirmationPrayerPhase.setup);
      expect(narration.spoken, isEmpty);
      expect(bed.playing, isNull);
    });
  });

  group('counting', () {
    test('audio replay never advances an affirmation count', () async {
      final controller = buildController();

      await controller.begin();
      await controller.hearAgain();

      expect(controller.state.stepOneCount, 0);
      await controller.confirmSpoken();
      expect(controller.state.stepOneCount, 1);
    });

    test('a tap advances exactly one repetition', () async {
      final controller = buildController();
      await controller.begin();

      await controller.confirmSpoken();
      await controller.confirmSpoken();

      expect(controller.state.stepOneCount, 2);
      expect(controller.state.count, 2);
      expect(controller.countLabel, '2 of 50');
    });

    test(
      'narration reading the phrase alone never advances the count',
      () async {
        final controller = buildController();
        await controller.begin();

        // The guide finished speaking twice on its own.
        expect(narration.spoken, [stepOnePhrase]);
        expect(controller.state.stepOneCount, 0);
      },
    );

    test('places the count quietly below the phrase', () async {
      final controller = buildController();
      await controller.begin();
      for (var index = 0; index < 12; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }

      expect(controller.currentPhrase, stepOnePhrase);
      expect(controller.countLabel, '12 of 50');
    });
  });

  group('group of ten', () {
    test('offers an untimed focused pause after each group of ten', () async {
      final controller = buildController();
      await controller.begin();

      for (var index = 0; index < 9; index++) {
        await controller.confirmSpoken();
        expect(controller.state.phase, AffirmationPrayerPhase.praying);
      }

      await controller.confirmSpoken();
      expect(controller.state.stepOneCount, 10);
      expect(controller.state.phase, AffirmationPrayerPhase.groupPause);
      expect(bed.duckCount, 1);
      // The guide stops for the pause.
      expect(narration.stopCount, greaterThan(0));

      await controller.leaveGroupPause();
      expect(controller.state.phase, AffirmationPrayerPhase.praying);
      expect(bed.restoreCount, 1);
    });

    test('ducks the chosen bed for every group of ten', () async {
      final controller = buildController();
      // The guide's own readings are ducked on the same mechanism, so it is
      // switched off here to count only the group boundaries.
      await controller.setGuideEnabled(false);
      await controller.setSound(soundKey: 'ocean_waves', volume: .15);
      await controller.begin();

      for (var index = 0; index < 20; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }

      expect(controller.state.stepOneCount, 20);
      expect(bed.duckCount, 2);
    });

    test('ducks under the spoken prayer without silencing the bed', () async {
      final controller = buildController();
      await controller.setSound(soundKey: 'tenThousandReasons', volume: .20);

      await controller.begin();

      // The guide read the phrase, so the bed was lowered for it and then put
      // back — one pair, on the existing duck/restore mechanism.
      expect(bed.duckCount, 1);
      expect(bed.restoreCount, 1);
      expect(
        bed.playing,
        'tenThousandReasons',
        reason: 'the bed keeps playing',
      );
      expect(bed.volume, closeTo(.20, .001));

      await controller.hearAgain();

      expect(bed.duckCount, 2, reason: 'a repeat is ducked the same way');
      expect(bed.restoreCount, 2);
      expect(bed.volume, closeTo(.20, .001));
    });

    test('leaves the bed ducked, not silenced, under the guide', () async {
      final bed = _RecordingSoundBed();
      final controller = AffirmationPrayerSessionController(
        profile: buildProfile(),
        releaseItemId: 'release-item-3',
        sessionId: 'session-1',
        narration: narration,
        soundBed: bed,
        awake: awake,
        saveSession: () => sessions,
        now: () => DateTime.utc(2026, 10, 6, 9),
      );
      addTearDown(controller.dispose);

      await controller.setSound(soundKey: 'tenThousandReasons', volume: .20);
      await controller.begin();

      // While the guide reads, the bed is audible and simply lower. Silence
      // would be `0`; a duck is a reduction.
      expect(bed.levels, [0.20, closeTo(0.08, 1e-9), closeTo(0.20, 1e-9)]);
      expect(bed.levels.every((level) => level > 0), isTrue);
    });

    test(
      'a pause keeps the bed ducked after the guide stops mid-phrase',
      () async {
        final bed = _RecordingSoundBed();
        final narration = _BlockingNarration();
        final controller = AffirmationPrayerSessionController(
          profile: buildProfile(),
          releaseItemId: 'release-item-3',
          sessionId: 'session-1',
          narration: narration,
          soundBed: bed,
          awake: awake,
          saveSession: () => sessions,
          now: () => DateTime.utc(2026, 10, 6, 9),
        );
        addTearDown(controller.dispose);

        await controller.setSound(soundKey: 'tenThousandReasons', volume: .20);
        final begun = controller.begin();
        await narration.reading.future;

        // The guide is still reading when the tenth repetition arrives, so the
        // group boundary and the guide's own duck land at the same moment.
        for (var index = 0; index < 10; index++) {
          await controller.confirmSpoken();
        }
        expect(controller.state.phase, AffirmationPrayerPhase.groupPause);

        await controller.pause();
        await begun;

        // The bed was lowered for the guide, lowered again by the pause, and
        // never raised: the pause owns the ducked level, so the guide's own
        // restore does not lift it on the way out. Every level asked for is
        // above zero, because a duck is a reduction and never a mute.
        expect(bed.levels.first, closeTo(0.20, 1e-9));
        expect(bed.levels.skip(1), everyElement(closeTo(0.08, 1e-9)));
        expect(bed.levels.every((level) => level > 0), isTrue);
        expect(bed.playing, isNull);
      },
    );
  });

  group('step transition', () {
    test(
      'moves quietly from fifty to ten after the fiftieth repetition',
      () async {
        final controller = buildController();
        await controller.begin();

        for (var index = 0; index < 50; index++) {
          await controller.confirmSpoken();
          if (index < 49 &&
              controller.state.phase == AffirmationPrayerPhase.groupPause) {
            await controller.leaveGroupPause();
          }
        }

        expect(controller.state.stepOneCount, 50);
        // The fiftieth repetition pauses before the second phrase begins.
        expect(controller.state.phase, AffirmationPrayerPhase.groupPause);

        await controller.leaveGroupPause();

        expect(controller.state.stepOneCount, 50);
        expect(controller.state.stepTwoCount, 0);
        expect(controller.state.stepIndex, 1);
        expect(controller.currentPhrase, stepTwoPhrase);
        expect(controller.countLabel, '0 of 10');
      },
    );

    test('counts the second phrase from zero of ten', () async {
      final controller = buildController();
      await controller.begin();

      for (var index = 0; index < 60; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }

      expect(controller.state.stepOneCount, 50);
      expect(controller.state.stepTwoCount, 10);
    });
  });

  group('terminal records', () {
    Future<AffirmationPrayerSessionController> finished({
      required int stepOneCount,
      required int stepTwoCount,
    }) async {
      final controller = buildController();
      await controller.begin();
      for (var index = 0; index < stepOneCount; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }
      for (var index = 0; index < stepTwoCount; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }

      return controller;
    }

    test('records a completed session after fifty and ten', () async {
      final controller = await finished(stepOneCount: 50, stepTwoCount: 10);

      expect(controller.state.phase, AffirmationPrayerPhase.completed);
      expect(sessions.saved, hasLength(1));
      expect(sessions.saved.single.outcome, AffirmationPrayerOutcome.completed);
      expect(sessions.saved.single.stepOneCount, 50);
      expect(sessions.saved.single.stepTwoCount, 10);
      expect(sessions.saved.single.localDate, '2026-10-06');
    });

    test('records the actual counts when ended early', () async {
      final controller = buildController();
      await controller.begin();
      for (var index = 0; index < 12; index++) {
        await controller.confirmSpoken();
        if (controller.state.phase == AffirmationPrayerPhase.groupPause) {
          await controller.leaveGroupPause();
        }
      }
      await controller.end();

      expect(sessions.saved, hasLength(1));
      expect(
        sessions.saved.single.outcome,
        AffirmationPrayerOutcome.endedEarly,
      );
      expect(sessions.saved.single.stepOneCount, 12);
      expect(sessions.saved.single.stepTwoCount, 0);
    });

    test('records nothing at the very start', () async {
      final controller = buildController();
      await controller.begin();
      await controller.end();

      expect(
        sessions.saved.single.outcome,
        AffirmationPrayerOutcome.endedEarly,
      );
      expect(sessions.saved.single.stepOneCount, 0);
    });

    test('never writes a second terminal record', () async {
      final controller = await finished(stepOneCount: 50, stepTwoCount: 10);
      await controller.end();
      await controller.retrySave();

      expect(sessions.saved, hasLength(1));
    });

    test('retries the same record after a failed save', () async {
      final controller = buildController();
      await controller.begin();
      sessions.shouldFail = true;
      await controller.end();

      expect(controller.state.saveFailed, isTrue);
      expect(sessions.saved, isEmpty);

      sessions.shouldFail = false;
      await controller.retrySave();

      expect(sessions.saved, hasLength(1));
      expect(controller.state.saved, isTrue);
      expect(controller.state.saveFailed, isFalse);
    });

    test('rejects a completed record with incomplete counts', () {
      expect(
        () => AffirmationPrayerSession.validate(
          outcome: AffirmationPrayerOutcome.completed,
          stepOneCount: 49,
          stepTwoCount: 10,
          startedAt: DateTime.utc(2026, 10, 6, 9),
          endedAt: DateTime.utc(2026, 10, 6, 9, 5),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects counts beyond either target', () {
      expect(
        () => AffirmationPrayerSession.validate(
          outcome: AffirmationPrayerOutcome.endedEarly,
          stepOneCount: 51,
          stepTwoCount: 0,
          startedAt: DateTime.utc(2026, 10, 6, 9),
          endedAt: DateTime.utc(2026, 10, 6, 9, 5),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a session that ends before it starts', () {
      expect(
        () => AffirmationPrayerSession.validate(
          outcome: AffirmationPrayerOutcome.endedEarly,
          stepOneCount: 12,
          stepTwoCount: 0,
          startedAt: DateTime.utc(2026, 10, 6, 9, 12),
          endedAt: DateTime.utc(2026, 10, 6, 9),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts a session that ends at the moment it started', () {
      expect(
        () => AffirmationPrayerSession.validate(
          outcome: AffirmationPrayerOutcome.endedEarly,
          stepOneCount: 0,
          stepTwoCount: 0,
          startedAt: DateTime.utc(2026, 10, 6, 9),
          endedAt: DateTime.utc(2026, 10, 6, 9),
        ),
        returnsNormally,
      );
    });
  });

  group('lifecycle', () {
    test(
      'stops sound on an interruption and resumes only on request',
      () async {
        final controller = buildController();
        await controller.setSound(soundKey: 'gentle_rain', volume: .15);
        await controller.begin();
        expect(bed.playing, 'gentle_rain');

        await controller.pauseForInterruption();
        expect(bed.playing, isNull);
        expect(narration.stopCount, greaterThan(0));
        expect(awake.states.last, isFalse);

        // Foregrounding alone must not bring sound back.
        controller.becameVisible();
        await Future<void>.delayed(Duration.zero);
        expect(bed.playing, isNull);

        await controller.resume();
        expect(bed.playing, 'gentle_rain');
      },
    );

    test('keeps the device awake while the session is active', () async {
      final controller = buildController();
      await controller.begin();

      expect(awake.states, contains(true));
    });

    test('a deliberate pause stops the sound immediately', () async {
      final controller = buildController();
      await controller.setSound(soundKey: 'forest_morning', volume: .2);
      await controller.begin();
      await controller.pause();

      expect(bed.playing, isNull);
      expect(controller.state.phase, AffirmationPrayerPhase.setup);
    });
  });

  group('setup', () {
    test('offers only the four approved paces and defaults to 0.85x', () async {
      expect(AffirmationPrayerSessionController.availableSpeeds, [
        .70,
        .85,
        1.0,
        1.15,
      ]);

      final controller = buildController();
      expect(controller.state.speed, .85);

      await controller.setSpeed(.70);
      expect(controller.state.speed, .70);

      await controller.setSpeed(1.15);
      expect(controller.state.speed, 1.15);

      await controller.setSpeed(1.4);
      expect(controller.state.speed, 1.15);
    });

    test(
      'keeps the selected sound and level with the session record',
      () async {
        final controller = buildController();
        await controller.setSound(soundKey: 'ocean_waves', volume: .2);
        await controller.begin();
        await controller.end();

        expect(sessions.saved.single.soundKey, 'ocean_waves');
        expect(sessions.saved.single.narrationSpeed, .85);
      },
    );

    test('starts the chosen bed only after a deliberate begin', () async {
      final controller = buildController();
      await controller.setSound(soundKey: 'soft_wind', volume: .15);

      expect(bed.playing, isNull);
      await controller.begin();
      expect(bed.playing, 'soft_wind');
    });

    test('never sounds the guide when it is switched off', () async {
      final controller = buildController();
      await controller.setGuideEnabled(false);
      await controller.begin();

      expect(narration.spoken, isEmpty);
    });
  });
}
