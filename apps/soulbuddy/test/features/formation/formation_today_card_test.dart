import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/features/formation/presentation/formation_today_card.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';

void main() {
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
      expect(find.byKey(const Key('formation-piece-orientation')), findsOneWidget);
      expect(find.byKey(const Key('orientation-path')), findsOneWidget);
      expect(find.byKey(const Key('orientation-path-marker-0')), findsOneWidget);
      expect(find.byKey(const Key('orientation-path-marker-7')), findsOneWidget);

      await tester.tap(find.text('Continue orientation'));
      await tester.pumpAndSettle();
      expect(find.text('Opened 03-make-room-to-listen'), findsOneWidget);
    },
  );
}
