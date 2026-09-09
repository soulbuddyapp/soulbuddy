import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/application/orientation_controller.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';

const course = OrientationCourse(
  id: 'welcome',
  title: 'Welcome',
  tenet: 'Begin',
  audioAsset: 'audio.mp3',
  transcriptAsset: 'transcript.json',
  duration: Duration(seconds: 30),
);
final transcript = OrientationTranscript.fromJson({
  'text': 'Hello.',
  'durationMs': 30000,
  'words': [
    {'startMs': 0, 'endMs': 1000, 'charStart': 0, 'charEnd': 6},
  ],
  'sentences': [
    {'startMs': 0, 'endMs': 1000, 'charStart': 0, 'charEnd': 6},
  ],
});

void main() {
  late FakePlayer player;
  late OrientationProgressRepository repository;
  late OrientationController controller;
  late Map<String, String> storage;
  var failProgressReads = false;
  var failPreferenceReads = false;
  var progressReads = 0;
  var preferenceReads = 0;
  setUp(() {
    storage = <String, String>{};
    failProgressReads = false;
    failPreferenceReads = false;
    progressReads = 0;
    preferenceReads = 0;
    player = FakePlayer();
    repository = OrientationProgressRepository(
      read: (key) async {
        if (key.contains('.progress.')) {
          progressReads++;
          if (failProgressReads) throw StateError('read unavailable');
        } else {
          preferenceReads++;
          if (failPreferenceReads) throw StateError('preferences unavailable');
        }
        return storage[key];
      },
      write: (key, value) async {
        storage[key] = value;
      },
    );
    controller = OrientationController(
      course: course,
      transcript: transcript,
      player: player,
      repository: repository,
    );
  });
  tearDown(() async {
    await controller.close();
    controller.dispose();
  });

  test('restores position and preferences without autoplay', () async {
    await repository.save(
      course.id,
      const OrientationProgress(position: Duration(seconds: 8)),
    );
    await repository.savePreferences(
      const OrientationPreferences(speed: .85, textScale: 1.3),
    );
    await controller.initialize();
    expect(controller.position.inSeconds, 8);
    expect(controller.speed, .85);
    expect(controller.textScale, 1.3);
    expect(player.playCalls, 0);
    expect(player.seeked.last.inSeconds, 8);
    expect(controller.loading, false);
  });

  test(
    'media position drives state and saves at five second intervals',
    () async {
      await controller.initialize();
      await controller.toggle();
      player.positionEvents.add(const Duration(seconds: 6));
      await flush();
      expect(controller.position.inSeconds, 6);
      expect((await repository.load(course.id)).position.inSeconds, 6);
      await controller.setSpeed(1.5);
      player.positionEvents.add(const Duration(seconds: 8));
      await flush();
      expect(controller.position.inSeconds, 8);
      await controller.pause();
      expect((await repository.load(course.id)).position.inSeconds, 8);
    },
  );

  test(
    'seeking to the end does not mark completion; ended does and can replay',
    () async {
      await controller.initialize();
      await controller.seek(course.duration);
      expect(controller.completed, false);
      await controller.startAgain();
      await controller.toggle();
      player.completionEvents.add(null);
      await flush();
      expect(controller.completed, true);
      expect((await repository.load(course.id)).completed, true);
      await controller.toggle();
      expect(controller.position, Duration.zero);
      expect(controller.playing, true);
      expect(controller.completed, true);
    },
  );

  test(
    'seek discards position events while the backend seek is pending',
    () async {
      await controller.initialize();
      await controller.toggle();
      player.positionEvents.add(const Duration(seconds: 20));
      await flush();
      player.seekGate = Completer<void>();
      final seeking = controller.seek(const Duration(seconds: 3));
      await flush();
      player.positionEvents.add(const Duration(seconds: 21));
      await flush();
      expect(controller.position.inSeconds, 20);
      player.seekGate!.complete();
      await seeking;
      expect(controller.position.inSeconds, 3);
      player.positionEvents.add(const Duration(milliseconds: 3050));
      await flush();
      expect(controller.position.inMilliseconds, 3050);
    },
  );

  test(
    'delayed first sample after seeking updates highlights and progress',
    () async {
      await controller.initialize();
      await controller.toggle();
      await controller.seek(const Duration(seconds: 3));
      // At 1.5x, a delayed backend query can report well beyond the target.
      await controller.setSpeed(1.5);
      player.positionEvents.add(const Duration(seconds: 9));
      await flush();
      expect(controller.position.inSeconds, 9);
      expect((await repository.load(course.id)).position.inSeconds, 9);
      player.positionEvents.add(const Duration(seconds: 10));
      await flush();
      expect(controller.position.inSeconds, 10);
    },
  );

  test(
    'a backend-clamped end seek reconciles to its actual media position',
    () async {
      await controller.initialize();
      await controller.seek(course.duration);
      player.positionEvents.add(const Duration(milliseconds: 29000));
      await flush();
      expect(controller.position.inMilliseconds, 29000);
      expect(controller.completed, false);
    },
  );

  test(
    'failed progress read preserves stored record and retries independently',
    () async {
      await repository.save(
        course.id,
        const OrientationProgress(
          position: Duration(seconds: 17),
          completed: true,
        ),
      );
      await repository.savePreferences(
        const OrientationPreferences(speed: .85, textScale: 1.3),
      );
      failProgressReads = true;
      await controller.initialize();
      expect(controller.speed, .85);
      expect(controller.persistenceWarning, isNotNull);
      await controller.pause();
      await controller.setTextScale(1.4);
      expect(controller.persistenceWarning, isNotNull);
      failProgressReads = false;
      final saved = await repository.load(course.id);
      expect(saved.position.inSeconds, 17);
      expect(saved.completed, true);
      await controller.initialize();
      expect(controller.position.inSeconds, 17);
      expect(controller.completed, true);
      expect(controller.textScale, 1.4);
      expect(controller.playing, false);
      expect(controller.persistenceWarning, isNull);
      expect(preferenceReads, 1);
    },
  );

  test(
    'close after a failed read does not erase unread stored progress',
    () async {
      await repository.save(
        course.id,
        const OrientationProgress(
          position: Duration(seconds: 17),
          completed: true,
        ),
      );
      failProgressReads = true;
      await controller.initialize();
      await controller.close();
      failProgressReads = false;
      final saved = await repository.load(course.id);
      expect(saved.position.inSeconds, 17);
      expect(saved.completed, true);
    },
  );

  test(
    'preference retry does not reread or reset successfully restored progress',
    () async {
      await repository.save(
        course.id,
        const OrientationProgress(position: Duration(seconds: 17)),
      );
      await repository.savePreferences(
        const OrientationPreferences(speed: .75, textScale: 1.3),
      );
      failPreferenceReads = true;
      await controller.initialize();
      expect(controller.position.inSeconds, 17);
      await controller.seek(const Duration(seconds: 12));
      expect(controller.persistenceWarning, isNotNull);
      failPreferenceReads = false;
      await controller.initialize();
      expect(controller.position.inSeconds, 12);
      expect(controller.speed, .75);
      expect(controller.textScale, 1.3);
      expect(controller.persistenceWarning, isNull);
      expect(progressReads, 1);
      expect(preferenceReads, 2);
    },
  );

  test(
    'failed preparation can retry and storage failures remain nonfatal',
    () async {
      player.failPrepare = true;
      await controller.initialize();
      expect(controller.error, isNotNull);
      expect(controller.loading, false);
      player.failPrepare = false;
      await controller.initialize();
      expect(controller.error, isNull);
      await controller.toggle();
      expect(controller.playing, true);
    },
  );

  test('changing speed cannot autoplay a paused native engine', () async {
    await controller.initialize();
    player.resumeOnRate = true;
    await controller.setSpeed(.75);
    expect(controller.playing, false);
    expect(player.isPlaying, false);
  });

  test('retry retains latest position and persisted completion', () async {
    await controller.initialize();
    await controller.seek(const Duration(seconds: 12));
    player.positionEvents.add(const Duration(milliseconds: 12500));
    await flush();
    player.positionEvents.addError(StateError('interrupted'));
    await flush();
    expect(controller.error, isNotNull);
    await controller.initialize();
    expect(controller.position.inMilliseconds, 12500);
    expect(controller.playing, false);
    expect(controller.error, isNull);
  });

  test('storage failure is nonfatal and a later save can recover', () async {
    await controller.close();
    controller.dispose();
    player = FakePlayer();
    var fails = true;
    repository = OrientationProgressRepository(
      read: (_) async => null,
      write: (_, __) async {
        if (fails) throw StateError('quota');
      },
    );
    controller = OrientationController(
      course: course,
      transcript: transcript,
      player: player,
      repository: repository,
    );
    await controller.initialize();
    await controller.toggle();
    await controller.seek(const Duration(seconds: 9));
    expect(controller.error, isNull);
    expect(controller.persistenceWarning, isNotNull);
    expect(controller.playing, true);
    fails = false;
    await controller.pause();
    expect(controller.persistenceWarning, isNull);
  });

  test(
    'leaving before initialization starts cannot erase existing progress',
    () async {
      await repository.save(
        course.id,
        const OrientationProgress(
          position: Duration(seconds: 17),
          completed: true,
        ),
      );
      final initializing = controller.initialize();
      await controller.close();
      await initializing;
      final saved = await repository.load(course.id);
      expect(saved.position.inSeconds, 17);
      expect(saved.completed, true);
    },
  );

  test(
    'rapid seek actions execute in order and persist the last target',
    () async {
      await controller.initialize();
      player.seekGate = Completer<void>();
      final first = controller.seek(const Duration(seconds: 7));
      final second = controller.seek(const Duration(seconds: 13));
      await flush();
      expect(player.seeked, [const Duration(seconds: 7)]);
      player.seekGate!.complete();
      await Future.wait([first, second]);
      expect(player.seeked.last.inSeconds, 13);
      expect((await repository.load(course.id)).position.inSeconds, 13);
    },
  );

  test(
    'close is idempotent and no pending initialization can start playback',
    () async {
      player.prepareGate = Completer<void>();
      final initializing = controller.initialize();
      await flush();
      final closing = controller.close();
      controller.dispose();
      player.prepareGate!.complete();
      await initializing;
      await closing;
      await controller.toggle();
      await controller.close();
      expect(player.playCalls, 0);
      expect(player.closeCalls, 1);
    },
  );
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakePlayer implements OrientationPlayer {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final playingEvents = StreamController<bool>.broadcast(sync: true);
  final completionEvents = StreamController<void>.broadcast(sync: true);
  Completer<void>? seekGate;
  Completer<void>? prepareGate;
  bool failPrepare = false;
  bool resumeOnRate = false;
  bool isPlaying = false;
  int playCalls = 0;
  int closeCalls = 0;
  final seeked = <Duration>[];
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<bool> get playing => playingEvents.stream;
  @override
  Stream<void> get completions => completionEvents.stream;
  @override
  Future<void> prepare(String audioAsset) async {
    await prepareGate?.future;
    if (failPrepare) throw StateError('missing audio');
  }

  @override
  Future<void> play() async {
    playCalls++;
    isPlaying = true;
    playingEvents.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    playingEvents.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeked.add(position);
    await seekGate?.future;
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (resumeOnRate) {
      isPlaying = true;
      playingEvents.add(true);
    }
  }

  @override
  Future<void> close() async {
    closeCalls++;
    await positionEvents.close();
    await playingEvents.close();
    await completionEvents.close();
  }
}
