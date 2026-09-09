import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/orientation/application/orientation_controller.dart';
import 'package:soulbuddy/features/orientation/application/orientation_player.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/domain/orientation_course.dart';
import 'package:soulbuddy/features/orientation/presentation/orientation_reader_screen.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all bundled courses parse through the app providers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final courses = await container.read(orientationCatalogProvider.future);
    expect(courses, hasLength(8));
    expect(courses.map((course) => course.id).toSet(), hasLength(8));
    for (final course in courses) {
      final transcript = await container.read(
        orientationTranscriptProvider(course.transcriptAsset).future,
      );
      expect(transcript.duration, course.duration, reason: course.id);
      expect(transcript.words, isNotEmpty, reason: course.id);
      expect(transcript.sentences, isNotEmpty, reason: course.id);
      final data =
          jsonDecode(await rootBundle.loadString(course.transcriptAsset))
              as Map<String, dynamic>;
      expect(data['id'], course.id);
      expect(data['title'], course.title);
      expect(data['tenet'], course.tenet);
      expect(course.audioAsset, 'orientation/${course.id}.mp3');
      final audio = await rootBundle.load('assets/${course.audioAsset}');
      expect(audio.lengthInBytes, greaterThan(1000), reason: course.id);
      String normalize(String text) =>
          text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final cues in [transcript.words, transcript.sentences]) {
        expect(
          normalize(
            cues
                .map(
                  (cue) =>
                      transcript.text.substring(cue.charStart, cue.charEnd),
                )
                .join(),
          ),
          normalize(transcript.text),
          reason: course.id,
        );
      }
    }
  });

  test('corrected full teaching parses and ships complete audio', () async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/orientation/full-course.json'),
    );
    final transcript = OrientationTranscript.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
    final audio = await rootBundle.load('assets/orientation/full-course.mp3');

    expect(transcript.duration, greaterThan(const Duration(minutes: 10)));
    expect(data['timingSource'], 'speech-engine-word-boundaries');
    expect(transcript.text, contains('Aim for a plentiful harvest'));
    expect(
      transcript.text,
      contains('Plant something good in the garden each day'),
    );
    expect(
      transcript.text.toLowerCase(),
      isNot(contains('garden must bear fruit')),
    );
    expect(audio.lengthInBytes, greaterThan(1000000));
  });

  testWidgets(
    'audio and storage failures keep reading usable at 2x with Skip',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const course = OrientationCourse(
        id: 'welcome',
        title: 'Aim for a plentiful harvest',
        tenet: 'Welcome',
        audioAsset: 'orientation/welcome.mp3',
        transcriptAsset: 'welcome.json',
        duration: Duration(seconds: 10),
      );
      const text = 'Plant something good in the garden each day.';
      final transcript = OrientationTranscript.fromJson({
        'text': text,
        'durationMs': 10000,
        'words': [
          {'startMs': 0, 'endMs': 5000, 'charStart': 0, 'charEnd': text.length},
        ],
        'sentences': [
          {'startMs': 0, 'endMs': 5000, 'charStart': 0, 'charEnd': text.length},
        ],
      });
      final player = _UnavailablePlayer();
      final controller = OrientationController(
        course: course,
        transcript: transcript,
        player: player,
        repository: OrientationProgressRepository(
          read: (_) async => throw StateError('Storage unavailable'),
          write: (_, _) async => throw StateError('Storage unavailable'),
        ),
      );
      var skipped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
              ),
              child: OrientationReaderScreen(
                course: course,
                transcript: transcript,
                controller: controller,
                onBack: () {},
                onSkip: () async {
                  skipped = true;
                },
                reduceMotion: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.error, isNotNull);
      expect(controller.persistenceWarning, isNotNull);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('orientation-transcript'))).height,
        greaterThanOrEqualTo(140),
      );
      expect(find.text(text), findsOneWidget);
      expect(find.text('Skip for now').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('orientation-status')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(controller.error!), findsOneWidget);
      final warning = find.text(controller.persistenceWarning!);
      await tester.ensureVisible(warning);
      await tester.pumpAndSettle();
      expect(warning.hitTestable(), findsOneWidget);
      final retry = find.text('Try audio again');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(player.prepareAttempts, 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
      expect(player.closed, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class _UnavailablePlayer implements OrientationPlayer {
  bool closed = false;
  int prepareAttempts = 0;
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> prepare(String asset) async {
    prepareAttempts++;
    throw StateError('Audio unavailable');
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> close() async {
    closed = true;
  }
}
