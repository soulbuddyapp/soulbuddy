import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/commitments/application/commitment_audio.dart';
import 'package:soulbuddy/features/commitments/application/commitment_meditation_session_controller.dart';
import 'package:soulbuddy/features/commitments/domain/commitment.dart';
import 'package:soulbuddy/features/commitments/presentation/commitment_meditation_screen.dart';

import 'commitment_meditation_controller_test.dart' show FakeSessionAudio;

void main() {
  late CommitmentMeditationSessionController controller;
  late FakeSessionAudio guide, bell;
  late List<CommitmentMeditationSessionDraft> saved;
  var elapsed = Duration.zero;
  var memoryOpened = false;
  var exited = false;
  final at = DateTime(2026, 9, 26, 9);
  final details = CommitmentDetails(
    commitment: Commitment(
      id: 'commitment',
      ownerId: 'owner',
      journeySlot: CommitmentJourneySlot.primary,
      goalId: 'goal',
      name: 'A faithful life',
      keyNeedOne: 'Private need',
      keyNeedTwo: 'Second need',
      keyNeedThree: 'Third need',
      calling: 'Private calling',
      guideId: CommitmentGuideId.peace,
      createdAt: at,
      updatedAt: at,
    ),
    practices: const [],
  );
  const asset = CommitmentAudioAsset(
    id: 'guide_peace_v1',
    path: 'unused.wav',
    transcript: 'Be still, and know that I am God. Now listen.',
    captions: [
      {
        'startMs': 0,
        'endMs': 1000,
        'text': 'Be still, and know that I am God.',
      },
    ],
    duration: Duration(seconds: 2),
  );

  void create({bool listening = false}) {
    elapsed = Duration.zero;
    saved = [];
    memoryOpened = false;
    exited = false;
    guide = FakeSessionAudio();
    bell = FakeSessionAudio();
    controller = CommitmentMeditationSessionController(
      commitmentId: 'commitment',
      sessionId: 'session',
      deviceId: 'device',
      kind: listening
          ? CommitmentSessionKind.listening
          : CommitmentSessionKind.meditation,
      guideId: listening ? 'listening_v1' : 'guide_peace_v1',
      plannedDuration: const Duration(minutes: 5),
      guide: guide,
      bell: bell,
      bed: FakeSessionAudio(),
      elapsed: () => elapsed,
      now: () => at.add(elapsed),
      autoTick: false,
      saveSession: (draft) async {
        saved.add(draft);
      },
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    bool listening = false,
    double scale = 1,
  }) async {
    create(listening: listening);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: CommitmentSessionView(
            details: details,
            controller: controller,
            guideAsset: asset,
            onExit: () {
              exited = true;
            },
            onRecordMemory: () {
              memoryOpened = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> timer(WidgetTester tester) async {
    await tester.tap(find.text('Begin session'));
    await tester.pump();
    guide.finish();
    await tester.pump();
    bell.finish();
    elapsed += const Duration(seconds: 2);
    controller.tick();
    await tester.pump();
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }

  testWidgets('explicit start, generic captions and optional saved memory', (
    tester,
  ) async {
    await mount(tester);
    expect(guide.starts, 0);
    expect(find.text('0.85x'), findsOneWidget);
    expect(find.text('Private need'), findsNothing);
    await tester.tap(find.text('Begin session'));
    await tester.pump();
    expect(find.text('Be still, and know that I am God.'), findsOneWidget);
    await tester.tap(find.text('End'));
    await tester.pump();
    expect(saved, hasLength(1));
    expect(memoryOpened, false);
    await tester.tap(find.text('Record a memory'));
    await tester.pump();
    expect(memoryOpened, true);
    await cleanup(tester);
  });

  testWidgets('background pauses timer and foreground does not resume', (
    tester,
  ) async {
    await mount(tester);
    await timer(tester);
    expect(controller.phase, CommitmentSessionPhase.timing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    elapsed += const Duration(minutes: 20);
    controller.tick();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.phase, CommitmentSessionPhase.paused);
    expect(saved, isEmpty);
    expect(find.text('Resume'), findsOneWidget);
    await cleanup(tester);
  });

  testWidgets(
    'private commitment details require deliberate expansion and pause',
    (tester) async {
      await mount(tester);
      await timer(tester);
      expect(find.text('Private calling'), findsNothing);
      await tester.tap(find.text('A faithful life'));
      await tester.pumpAndSettle();
      expect(controller.phase, CommitmentSessionPhase.paused);
      expect(find.text('Private calling'), findsOneWidget);
      expect(saved, isEmpty);
      await cleanup(tester);
    },
  );

  testWidgets(
    'Listening is accessible at 200 percent text on a compact screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, listening: true, scale: 2);
      expect(find.text('Listening and discernment'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Begin session').hitTestable(),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Begin session'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('End').hitTestable(), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End'));
      await tester.pump();
      expect(saved.single.sessionKind, CommitmentSessionKind.listening);
      expect(
        find.text('What might need prayer, Scripture, or wise counsel?'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('End').hitTestable(), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End'));
      await tester.pump();
      expect(exited, true);
      await cleanup(tester);
    },
  );

  test(
    'memory handoff carries only generic copy and the session local date',
    () {
      final uri = commitmentMemoryUri('2026-09-26');
      expect(uri.path, '/remember/capture');
      expect(uri.queryParameters['date'], '2026-09-26');
      expect(uri.queryParameters['source'], 'commitment');
      expect(
        uri.queryParameters['prompt'],
        'What do you want to remember from this time with God?',
      );
      expect(uri.toString(), isNot(contains('Private')));
      expect(uri.queryParameters.keys.toSet(), {
        'mode',
        'source',
        'date',
        'title',
        'prompt',
      });
    },
  );
}
