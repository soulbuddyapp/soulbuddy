import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/presentation/practice_audio_scope.dart';

void main() {
  testWidgets('stops on route push before its transition finishes', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final visible = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: PracticeAudioScope(
          onVisibilityChanged: visible.add,
          child: const Text('Reading'),
        ),
      ),
    );
    expect(visible.last, true);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Other')),
    );
    await tester.pump();
    expect(visible.last, false);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(visible.last, true);
  });

  testWidgets('stops on tab switch, app background and dispose', (
    tester,
  ) async {
    final visible = <bool>[];
    Widget app(bool active) => MaterialApp(
      home: TickerMode(
        enabled: active,
        child: PracticeAudioScope(
          onVisibilityChanged: visible.add,
          child: const Text('Reading'),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pumpWidget(app(false));
    expect(visible.last, false);
    await tester.pumpWidget(app(true));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(visible.last, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(visible.last, true);
    await tester.pumpWidget(const SizedBox());
    expect(visible.last, false);
  });

  testWidgets(
    'back stops immediately while the outgoing page is still mounted',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final visible = <bool>[];
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('Home')),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => PracticeAudioScope(
            onVisibilityChanged: visible.add,
            child: const Text('Reading'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      expect(visible.last, false);
      await tester.pumpAndSettle();
    },
  );
}
