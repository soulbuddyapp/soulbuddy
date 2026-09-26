import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_audio.dart';
import 'package:soulbuddy/features/commitments/application/commitment_meditation_session_controller.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';

class FakeSessionAudio extends ChangeNotifier
    implements CommitmentSessionAudio {
  @override
  bool complete = false;
  @override
  bool unavailable = false;
  @override
  Duration position = Duration.zero;
  @override
  CommitmentAudioAsset? asset;
  int starts = 0;
  int pauses = 0;
  double rate = .85;
  Completer<void>? speedGate;
  @override
  Future<void> playGuide(String id) async {
    starts++;
    complete = false;
  }

  @override
  Future<void> playPath(
    String path, {
    double volume = 1,
    bool loop = false,
  }) async {
    starts++;
    complete = false;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {
    pauses++;
  }

  @override
  Future<void> setSpeed(double speed) async {
    rate = speed;
    await speedGate?.future;
  }

  void finish() {
    complete = true;
    notifyListeners();
  }

  void fail() {
    unavailable = true;
    notifyListeners();
  }
}

void main() {
  late FakeSessionAudio guide, bell, bed;
  late CommitmentMeditationSessionController controller;
  late List<CommitmentMeditationSessionDraft> saved;
  var elapsed = Duration.zero;
  var failSave = false;
  setUp(() {
    elapsed = Duration.zero;
    failSave = false;
    guide = FakeSessionAudio();
    bell = FakeSessionAudio();
    bed = FakeSessionAudio();
    saved = [];
    controller = CommitmentMeditationSessionController(
      commitmentId: 'commitment',
      sessionId: 'stable-session',
      deviceId: 'device',
      kind: CommitmentSessionKind.meditation,
      guideId: 'guide_peace_v1',
      plannedDuration: const Duration(minutes: 5),
      guide: guide,
      bell: bell,
      bed: bed,
      elapsed: () => elapsed,
      now: () => DateTime(2026, 9, 26, 9).add(elapsed),
      autoTick: false,
      saveSession: (draft) async {
        saved.add(draft);
        if (failSave) throw StateError('unavailable');
      },
    );
  });
  tearDown(() => controller.dispose());

  Future<void> enterTimer() async {
    await controller.begin();
    guide.finish();
    await Future<void>.delayed(Duration.zero);
    bell.finish();
    elapsed += const Duration(seconds: 2);
    controller.tick();
  }

  test(
    'requires explicit start, plays guide and one bell before timed silence',
    () async {
      expect(guide.starts, 0);
      expect(controller.phase, CommitmentSessionPhase.preparation);
      await controller.begin();
      expect(controller.phase, CommitmentSessionPhase.guiding);
      guide.finish();
      await Future<void>.delayed(Duration.zero);
      expect(bell.starts, 1);
      expect(controller.phase, CommitmentSessionPhase.bell);
      bell.finish();
      expect(controller.phase, CommitmentSessionPhase.silence);
      elapsed += const Duration(seconds: 1);
      controller.tick();
      expect(controller.phase, CommitmentSessionPhase.silence);
      elapsed += const Duration(seconds: 1);
      controller.tick();
      expect(controller.phase, CommitmentSessionPhase.timing);
      expect(saved, isEmpty);
    },
  );

  test(
    'background pauses immediately and never resumes or saves automatically',
    () async {
      await enterTimer();
      elapsed += const Duration(seconds: 20);
      controller.tick();
      await controller.pauseForInterruption();
      final remaining = controller.remaining;
      elapsed += const Duration(hours: 1);
      controller.tick();
      expect(controller.remaining, remaining);
      expect(controller.phase, CommitmentSessionPhase.paused);
      expect(saved, isEmpty);
      expect(guide.pauses, greaterThan(0));
      await controller.resume();
      elapsed += const Duration(seconds: 10);
      controller.tick();
      expect(controller.remaining, remaining - const Duration(seconds: 10));
    },
  );

  test(
    'natural completion records once, even with repeated ticks and End',
    () async {
      await enterTimer();
      elapsed += const Duration(minutes: 5);
      controller.tick();
      await Future<void>.delayed(Duration.zero);
      await controller.end();
      controller.tick();
      expect(saved, hasLength(1));
      expect(
        saved.single.outcome,
        CommitmentMeditationSessionOutcome.completed,
      );
      expect(saved.single.actualDurationSeconds, 300);
      expect(controller.saved, true);
    },
  );

  test('End during guidance records an honest zero-second early end', () async {
    await controller.begin();
    await controller.end();
    expect(saved.single.actualDurationSeconds, 0);
    expect(saved.single.outcome, CommitmentMeditationSessionOutcome.endedEarly);
  });

  test(
    'failed save retries the same immutable session without replaying audio',
    () async {
      await enterTimer();
      failSave = true;
      await controller.end();
      final draft = saved.single;
      expect(controller.saveFailed, true);
      expect(controller.saved, false);
      failSave = false;
      await controller.retrySave();
      expect(identical(saved.last, draft), true);
      expect(saved.last.id, 'stable-session');
      expect(controller.saved, true);
      expect(bell.starts, 1);
    },
  );

  test(
    'missing guide requires explicit transcript continuation and missing bell continues',
    () async {
      await controller.begin();
      guide.fail();
      expect(controller.phase, CommitmentSessionPhase.guiding);
      expect(controller.guideUnavailable, true);
      await controller.continueAfterGuide();
      bell.fail();
      expect(controller.phase, CommitmentSessionPhase.silence);
    },
  );

  test('pausing the deliberate silence excludes background time', () async {
    await controller.begin();
    guide.finish();
    await Future<void>.delayed(Duration.zero);
    bell.finish();
    elapsed += const Duration(seconds: 1);
    await controller.pauseForInterruption();
    elapsed += const Duration(minutes: 10);
    await controller.resume();
    controller.tick();
    expect(controller.phase, CommitmentSessionPhase.silence);
    elapsed += const Duration(seconds: 1);
    controller.tick();
    expect(controller.phase, CommitmentSessionPhase.timing);
  });

  test(
    'consented personal prayer remains opt-in and precedes generic guidance',
    () async {
      var personalStarts = 0;
      controller.playPersonalPrayer = () async {
        personalStarts++;
      };
      expect(controller.includePersonalPrayer, false);
      controller.includePersonalPrayer = true;
      await controller.begin();
      expect(personalStarts, 1);
      expect(guide.starts, 0);
      guide.finish();
      await Future<void>.delayed(Duration.zero);
      expect(guide.starts, 1);
      expect(controller.personalPrayerPlaying, false);
      expect(bell.starts, 0);
      expect(saved, isEmpty);
      guide.finish();
      await Future<void>.delayed(Duration.zero);
      expect(bell.starts, 1);
    },
  );

  test('Resume starts an interrupted guide load only once', () async {
    guide.speedGate = Completer<void>();
    final starting = controller.begin();
    await controller.pauseForInterruption();
    guide.speedGate!.complete();
    await starting;
    expect(guide.starts, 0);
    expect(saved, isEmpty);
    await controller.resume();
    expect(guide.starts, 1);
    expect(controller.phase, CommitmentSessionPhase.guiding);
  });

  test('Resume starts an interrupted bell load only once', () async {
    await controller.begin();
    bell.speedGate = Completer<void>();
    guide.finish();
    await Future<void>.delayed(Duration.zero);
    await controller.pauseForInterruption();
    bell.speedGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(bell.starts, 0);
    await controller.resume();
    expect(bell.starts, 1);
  });

  test('disposal stops without fabricating a session', () async {
    await enterTimer();
    controller.dispose();
    elapsed += const Duration(minutes: 10);
    controller.tick();
    await controller.end();
    expect(saved, isEmpty);
  });

  test(
    'failed optional personal narration falls back to generic guidance',
    () async {
      controller.includePersonalPrayer = true;
      controller.playPersonalPrayer = () async {
        throw StateError('unavailable');
      };
      await controller.begin();
      expect(guide.starts, 1);
      expect(controller.guideUnavailable, false);
      expect(controller.phase, CommitmentSessionPhase.guiding);
    },
  );
}
