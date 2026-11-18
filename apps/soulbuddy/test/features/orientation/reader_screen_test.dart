import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';
import 'package:soulbuddy/features/orientation/application/orientation_controller.dart';
import 'package:soulbuddy/features/orientation/presentation/orientation_reader_screen.dart';

void main() {
  testWidgets('prayer and goal responses remain in the reader', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrientationReaderScreen(
            course: fixture.course,
            transcript: fixture.transcript,
            controller: fixture.controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orientation-respond')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save a prayer'));
    await tester.tap(find.text('Save a prayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orientation-prayer-editor')), findsOneWidget);
    expect(find.byType(OrientationReaderScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Turn the seed into a Goal'));
    await tester.tap(find.text('Turn the seed into a Goal'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orientation-goal-editor')), findsOneWidget);
  });
  testWidgets('speed, playhead highlight and tap-to-seek stay connected', (
    tester,
  ) async {
    final fixture = _Fixture();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrientationReaderScreen(
            course: fixture.course,
            transcript: fixture.transcript,
            controller: fixture.controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.player.isPlaying, isFalse);
    await tester.tap(find.byKey(const Key('orientation-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.75×').last);
    await tester.pumpAndSettle();
    expect(fixture.player.speed, .75);
    await tester.tap(find.byKey(const Key('orientation-play')));
    await tester.pumpAndSettle();
    fixture.player.positionEvents.add(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orientation-active-word')), findsOneWidget);
    final sentence = find.byKey(const Key('orientation-sentence-2'));
    await tester.ensureVisible(sentence);
    await tester.tap(sentence);
    await tester.pumpAndSettle();
    expect(fixture.player.lastSeek, const Duration(milliseconds: 3000));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // Stream cancellation crosses the real event loop; pumping fake frames
    // alone does not finish teardown after the widget has been removed.
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(fixture.player.closed, isTrue);
  });

  testWidgets('manual scrolling suspends following until requested', (
    tester,
  ) async {
    final fixture = _Fixture();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrientationReaderScreen(
            course: fixture.course,
            transcript: fixture.transcript,
            controller: fixture.controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('orientation-transcript')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.text('Follow narration'), findsOneWidget);
    await tester.tap(find.text('Follow narration'));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('keyboard scrolling suspends following', (tester) async {
    final fixture = _Fixture();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrientationReaderScreen(
            course: fixture.course,
            transcript: fixture.transcript,
            controller: fixture.controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(
      find.byKey(const Key('orientation-sentence-0')),
    );
    Focus.of(element).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('Follow narration'), findsOneWidget);
    fixture.player.positionEvents.add(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Follow narration'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'large text on a small screen leaves transcript and controls usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
              ),
              child: OrientationReaderScreen(
                course: fixture.course,
                transcript: fixture.transcript,
                controller: fixture.controller,
                onBack: () {},
                reduceMotion: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('orientation-play')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class _Fixture {
  final values = <String, String>{};
  final player = _Player();
  late final course = OrientationCourse(
    id: 'test',
    title: 'Aim for a plentiful harvest',
    tenet: 'Welcome',
    audioAsset: 'orientation/test.mp3',
    transcriptAsset: 'test.json',
    duration: const Duration(seconds: 30),
  );
  late final transcript = _transcript();
  late final controller = OrientationController(
    course: course,
    transcript: transcript,
    player: player,
    repository: OrientationProgressRepository(
      read: (key) async => values[key],
      write: (key, value) async {
        values[key] = value;
      },
    ),
  );
}

OrientationTranscript _transcript() {
  final text = List.generate(
    18,
    (i) => 'Sentence $i invites us to plant something good today.',
  ).join('\n\n');
  final words = <Map<String, int>>[];
  final sentences = <Map<String, int>>[];
  var char = 0;
  for (var i = 0; i < 18; i++) {
    final line = 'Sentence $i invites us to plant something good today.';
    final matches = RegExp(r'\S+').allMatches(line).toList();
    for (var j = 0; j < matches.length; j++) {
      final m = matches[j];
      words.add({
        'startMs': i * 1500 + j * 150,
        'endMs': i * 1500 + (j + 1) * 150,
        'charStart': char + m.start,
        'charEnd': char + m.end,
      });
    }
    sentences.add({
      'startMs': i * 1500,
      'endMs': i * 1500 + 1400,
      'charStart': char,
      'charEnd': char + line.length,
    });
    char += line.length + 2;
  }
  return OrientationTranscript.fromJson({
    'text': text,
    'durationMs': 30000,
    'words': words,
    'sentences': sentences,
  });
}

class _Player implements OrientationPlayer {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final playingEvents = StreamController<bool>.broadcast(sync: true);
  final endedEvents = StreamController<void>.broadcast(sync: true);
  bool isPlaying = false, closed = false;
  double speed = 1;
  Duration lastSeek = Duration.zero;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<bool> get playing => playingEvents.stream;
  @override
  Stream<void> get completions => endedEvents.stream;
  @override
  Future<void> prepare(String asset) async {}
  @override
  Future<void> play() async {
    isPlaying = true;
    playingEvents.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    playingEvents.add(false);
  }

  @override
  Future<void> seek(Duration value) async {
    lastSeek = value;
    positionEvents.add(value);
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await positionEvents.close();
    await playingEvents.close();
    await endedEvents.close();
  }
}
