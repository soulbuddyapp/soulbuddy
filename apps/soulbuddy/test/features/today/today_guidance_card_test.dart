import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/today/domain/today_guidance.dart';
import 'package:soulbuddy/features/today/presentation/today_guidance_card.dart';

void main() {
  testWidgets('renders one compact reviewed next step', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayGuidanceCard(
            guidance: const TodayGuidanceCardValue(
              key: TodayGuidanceKey.rememberPerson,
              title: 'Remember someone in prayer',
              body: 'Add a person you want to pray for faithfully.',
              actionLabel: 'Add a person',
              route: '/persons/new',
            ),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('No practices available today'), findsNothing);
    expect(
      find.byKey(const Key('today-guidance-rememberPerson')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today-guidance-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today-guidance-action')));
    expect(opened, isTrue);
  });

  testWidgets('remains usable on a small phone at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TodayGuidanceCard(
                guidance: TodayGuidanceCardValue(
                  key: TodayGuidanceKey.remainClose,
                  title: 'Remain close',
                  body:
                      'You kept today’s routines. Give glory to God and remain close to Him.',
                  actionLabel: 'Open Remember',
                  route: '/remember',
                ),
                onOpen: _noop,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('today-guidance-action')), findsOneWidget);
  });
}

void _noop() {}
