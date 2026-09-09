import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/formation/presentation/formation_today_card.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'illustrated formation stays usable at width $width and scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                orientationJourneyStatusProvider.overrideWith(
                  (ref) async => const OrientationJourneyStatus(
                    completedCount: 0,
                    firstIncompleteId: '00-welcome',
                    started: false,
                    complete: false,
                  ),
                ),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: FormationTodayCard(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const Key('formation-today-action')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('formation-today-action')).hitTestable(),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets(
    'orientation takes priority and resumes its first unfinished Nugget',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FormationTodayCard()),
          GoRoute(
            path: '/orientation',
            builder: (_, state) =>
                Text('Opened ${state.uri.queryParameters['nugget']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orientationJourneyStatusProvider.overrideWith(
              (ref) async => const OrientationJourneyStatus(
                completedCount: 3,
                firstIncompleteId: '03-make-room-to-listen',
                started: true,
                complete: false,
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grow closer to God'), findsOneWidget);
      expect(find.text('3 of 8 Nuggets complete'), findsOneWidget);
      expect(find.text('Continue orientation'), findsOneWidget);
      expect(
        find.byKey(const Key('formation-piece-orientation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('orientation-path')), findsOneWidget);
      expect(
        find.byKey(const Key('orientation-path-marker-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('orientation-path-marker-7')),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue orientation'));
      await tester.pumpAndSettle();
      expect(find.text('Opened 03-make-room-to-listen'), findsOneWidget);
    },
  );
}
