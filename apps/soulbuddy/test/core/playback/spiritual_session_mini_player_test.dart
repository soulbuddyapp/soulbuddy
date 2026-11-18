import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/spiritual_session_mini_player.dart';
import 'package:soulbuddy/core/playback/spiritual_session_providers.dart';

void main() {
  testWidgets('persistent player provides a material layer for playback taps', (
    tester,
  ) async {
    final controller = SpiritualSessionController();
    await controller.begin(
      SpiritualSession(
        id: 'prayer-material',
        kind: SpiritualSessionKind.prayer,
        title: 'Prayer with a tap target',
        route: '/prayers/1',
        canPause: false,
        onPause: () async {},
        onResume: () async {},
        onComplete: () async {},
        onClose: () async {},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spiritualSessionControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(home: SpiritualSessionMiniPlayer(onOpen: (_) {})),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('persistent player pauses resumes opens and completes', (
    tester,
  ) async {
    final events = <String>[];
    final opened = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(
      SpiritualSession(
        id: 'prayer-1',
        kind: SpiritualSessionKind.prayer,
        title: 'Morning prayer',
        route: '/prayers/1',
        canPause: true,
        onPause: () async => events.add('pause'),
        onResume: () async => events.add('resume'),
        onComplete: () async => events.add('complete'),
        onClose: () async => events.add('close'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spiritualSessionControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(
          home: Scaffold(body: SpiritualSessionMiniPlayer(onOpen: opened.add)),
        ),
      ),
    );

    expect(
      find.byKey(const Key('spiritual-session-mini-player')),
      findsOneWidget,
    );
    expect(find.text('Morning prayer'), findsOneWidget);
    expect(find.byKey(const Key('spiritual-session-artwork')), findsOneWidget);
    expect(find.byKey(const Key('spiritual-session-progress')), findsOneWidget);
    expect(
      find.byKey(const Key('spiritual-session-piece-prayer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('spiritual-session-pause')));
    await tester.pump();
    expect(events, ['pause']);
    expect(find.byKey(const Key('spiritual-session-resume')), findsOneWidget);
    await tester.tap(find.text('Morning prayer'));
    expect(opened, ['/prayers/1']);
    await tester.tap(find.byKey(const Key('spiritual-session-complete')));
    await tester.pump();
    expect(events, ['pause', 'complete']);
    expect(
      find.byKey(const Key('spiritual-session-mini-player')),
      findsNothing,
    );
  });

  testWidgets('playback failure remains visible and can be closed', (
    tester,
  ) async {
    final controller = SpiritualSessionController();
    await controller.begin(
      SpiritualSession(
        id: 'failure',
        kind: SpiritualSessionKind.memory,
        title: 'My memory',
        route: '/remember/one',
        canPause: true,
        onPause: () async => throw StateError('Audio unavailable'),
        onResume: () async {},
        onComplete: () async {},
        onClose: () async {},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spiritualSessionControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(
          home: Scaffold(body: SpiritualSessionMiniPlayer(onOpen: (_) {})),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('spiritual-session-pause')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Playback could not continue.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spiritual-session-close')));
    await tester.pump();
    expect(find.text('My memory'), findsNothing);
  });
}
