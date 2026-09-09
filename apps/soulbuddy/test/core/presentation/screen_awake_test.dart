import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/presentation/screen_awake.dart';

void main() {
  testWidgets(
    'navigation and app background release the reading wake request',
    (tester) async {
      final values = <bool>[];
      final controller = ScreenAwakeController(
        apply: (v) async => values.add(v),
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: ScreenAwake(
            controller: controller,
            child: const Scaffold(body: Text('Reading')),
          ),
        ),
      );
      await controller.settled;
      expect(values.last, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await controller.settled;
      expect(values.last, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await controller.settled;
      expect(values.last, true);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other')),
        ),
      );
      await tester.pumpAndSettle();
      await controller.settled;
      expect(values.last, false);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await controller.settled;
      expect(values.last, true);
      await tester.pumpWidget(const SizedBox());
      await controller.settled;
      expect(values.last, false);
    },
  );

  test('wake requests share ownership and follow foreground state', () async {
    final values = <bool>[];
    final controller = ScreenAwakeController(apply: (v) async => values.add(v));
    final reading = Object();
    final prayer = Object();
    controller.acquire(reading);
    controller.acquire(prayer);
    controller.release(reading);
    await controller.settled;
    expect(values, [true]);
    controller.setForeground(false);
    controller.setForeground(true);
    controller.release(prayer);
    await controller.settled;
    expect(values, [true, false, true, false]);
  });

  testWidgets('hidden reading and disposed reading release screen awake', (
    tester,
  ) async {
    final values = <bool>[];
    final controller = ScreenAwakeController(apply: (v) async => values.add(v));
    Widget page(bool visible) => MaterialApp(
      home: TickerMode(
        enabled: visible,
        child: ScreenAwake(controller: controller, child: const Text('Prayer')),
      ),
    );
    await tester.pumpWidget(page(true));
    await controller.settled;
    expect(values, [true]);
    await tester.pumpWidget(page(false));
    await controller.settled;
    expect(values.last, false);
    await tester.pumpWidget(page(true));
    await tester.pumpWidget(const SizedBox());
    await controller.settled;
    expect(values, [true, false, true, false]);
  });
}
