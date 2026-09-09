import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/feedback/app_feedback_preferences.dart';
import 'package:soulbuddy/core/feedback/app_feedback_providers.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';
import 'package:soulbuddy/features/orientation/presentation/orientation_library_screen.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';

void main() {
  testWidgets(
    'next and previous save, close and resume adjacent lessons paused',
    (tester) async {
      final fixture = _Fixture();
      await fixture.repository.save(
        'lesson-2',
        const OrientationProgress(
          position: Duration(seconds: 11),
          completed: true,
        ),
      );
      await fixture.repository.savePreferences(
        const OrientationPreferences(speed: .85, textScale: 1.4),
      );
      await fixture.open(tester);
      expect(find.text('Nugget 1 of 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('orientation-speed')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.75×'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('orientation-play')));
      await tester.pumpAndSettle();
      final first = fixture.players.single;
      first.positionsController.add(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('orientation-next-course')));
      await _settleClose(tester);
      expect(first.closed, true);
      expect(first.isPlaying, false);
      expect((await fixture.repository.load('lesson-1')).position.inSeconds, 7);
      final second = fixture.players.last;
      expect(second.asset, 'lesson-2.mp3');
      expect(second.position.inSeconds, 11);
      expect(second.speed, .75);
      expect(second.isPlaying, false);
      expect(second.playCalls, 0);
      expect(find.text('Nugget 2 of 3'), findsOneWidget);
      expect(find.text('Orientation'), findsNothing);
      expect((await fixture.repository.loadPreferences()).textScale, 1.4);

      await tester.tap(find.byKey(const Key('orientation-previous-course')));
      await _settleClose(tester);
      expect(second.closed, true);
      expect(fixture.players.last.asset, 'lesson-1.mp3');
      expect(fixture.players.last.position.inSeconds, 7);
      expect(fixture.players.last.isPlaying, false);
      expect(find.text('Nugget 1 of 3'), findsOneWidget);
      expect((await fixture.repository.load('lesson-2')).completed, true);
      await tester.tap(find.byTooltip('Back to orientation'));
      await _settleClose(tester);
      expect(find.text('Orientation'), findsOneWidget);
      await fixture.unmount(tester);
    },
  );

  testWidgets('switching waits for shutdown and ignores repeated next taps', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.open(tester);
    final first = fixture.players.single;
    first.closeGate = Completer<void>();
    await tester.tap(find.byKey(const Key('orientation-next-course')));
    await _settleClose(tester);
    expect(fixture.players, hasLength(1));
    expect(find.text('Nugget 1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('orientation-next-course')));
    await tester.pump();
    first.closeGate!.complete();
    await _settleClose(tester);
    expect(first.closed, true);
    expect(fixture.players, hasLength(2));
    expect(find.text('Nugget 2 of 3'), findsOneWidget);
    await fixture.unmount(tester);
  });

  testWidgets(
    'course boundaries and skip remain usable at 2x with audio errors',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture()
        ..failAudio = true
        ..failReads = true;
      await fixture.open(tester, largeText: true);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('orientation-previous-course')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('orientation-next-course')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('orientation-transcript'))).height,
        greaterThanOrEqualTo(90),
      );
      expect(find.byKey(const Key('orientation-status')), findsOneWidget);
      await tester.tap(find.byKey(const Key('orientation-next-course')));
      await _settleClose(tester);
      await tester.tap(find.byKey(const Key('orientation-next-course')));
      await _settleClose(tester);
      expect(find.text('Nugget 3 of 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('orientation-next-course')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('orientation-previous-course')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Skip for now'));
      await _settleClose(tester);
      expect(fixture.skipped, true);
      expect(fixture.players.every((player) => player.closed), true);
      await fixture.unmount(tester);
    },
  );
}

Future<void> _settleClose(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

class _Fixture {
  final values = <String, String>{};
  final players = <_Player>[];
  bool skipped = false, failAudio = false, failReads = false;
  final courses = List.generate(
    3,
    (i) => OrientationCourse(
      id: 'lesson-${i + 1}',
      title: 'Lesson ${i + 1}',
      tenet: 'Grow in understanding',
      audioAsset: 'lesson-${i + 1}.mp3',
      transcriptAsset: 'lesson-${i + 1}.json',
      duration: const Duration(seconds: 30),
    ),
  );
  late final repository = OrientationProgressRepository(
    read: (key) async {
      if (failReads) throw StateError('unavailable');
      return values[key];
    },
    write: (key, value) async {
      values[key] = value;
    },
  );

  Future<void> open(WidgetTester tester, {bool largeText = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeedbackPreferencesProvider.overrideWith(
            (ref) => Stream.value(AppFeedbackPreferences.defaults),
          ),
          orientationCatalogProvider.overrideWith((ref) async => courses),
          orientationTranscriptProvider.overrideWith(
            (ref, path) async => const OrientationTranscript(
              text: 'Plant something good today. Let it grow with patience.',
              words: [
                TranscriptCue(
                  startMs: 0,
                  endMs: 15000,
                  charStart: 0,
                  charEnd: 27,
                ),
              ],
              sentences: [
                TranscriptCue(
                  startMs: 0,
                  endMs: 15000,
                  charStart: 0,
                  charEnd: 27,
                ),
                TranscriptCue(
                  startMs: 15000,
                  endMs: 30000,
                  charStart: 28,
                  charEnd: 53,
                ),
              ],
              duration: Duration(seconds: 30),
            ),
          ),
          orientationProgressRepositoryProvider.overrideWithValue(repository),
          orientationPlayerFactoryProvider.overrideWithValue(() {
            final player = _Player()..failPrepare = failAudio;
            players.add(player);
            return player;
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: largeText ? const Size(320, 568) : const Size(800, 600),
              textScaler: TextScaler.linear(largeText ? 2 : 1),
            ),
            child: OrientationLibraryScreen(
              onClose: () {},
              onSkip: () async {
                skipped = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lesson 1'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lesson 1'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _settleClose(tester);
  }
}

class _Player implements OrientationPlayer {
  final positionsController = StreamController<Duration>.broadcast(sync: true);
  final playingController = StreamController<bool>.broadcast(sync: true);
  final completionsController = StreamController<void>.broadcast(sync: true);
  Completer<void>? closeGate;
  bool isPlaying = false, closed = false, failPrepare = false;
  String? asset;
  Duration position = Duration.zero;
  double speed = 1;
  int playCalls = 0;
  @override
  Stream<Duration> get positions => positionsController.stream;
  @override
  Stream<bool> get playing => playingController.stream;
  @override
  Stream<void> get completions => completionsController.stream;
  @override
  Future<void> prepare(String value) async {
    asset = value;
    if (failPrepare) throw StateError('audio unavailable');
  }

  @override
  Future<void> play() async {
    playCalls++;
    isPlaying = true;
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    if (!closed) playingController.add(false);
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    positionsController.add(value);
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> close() async {
    await closeGate?.future;
    closed = true;
    await positionsController.close();
    await playingController.close();
    await completionsController.close();
  }
}
