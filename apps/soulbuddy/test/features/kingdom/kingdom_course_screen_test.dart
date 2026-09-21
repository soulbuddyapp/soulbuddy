import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/kingdom/presentation/kingdom_course_screen.dart';
import 'package:soulbuddy/features/orientation/data/orientation_progress_repository.dart';
import 'package:soulbuddy/features/orientation/providers/orientation_providers.dart';

void main() {
  testWidgets('completed Orientation reveals the Kingdom Nuggets', (
    tester,
  ) async {
    final repository = OrientationProgressRepository(
      read: (_) async => null,
      write: (_, _) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orientationProgressRepositoryProvider.overrideWith(
            (ref) => repository,
          ),
          orientationJourneyStatusProvider.overrideWith(
            (ref) async => const OrientationJourneyStatus(
              completedCount: 8,
              firstIncompleteId: null,
              started: true,
              complete: true,
            ),
          ),
        ],
        child: const MaterialApp(home: KingdomCourseScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Life in the Kingdom'), findsOneWidget);
    expect(
      find.byKey(const Key('kingdom-nugget-01-the-old-life')),
      findsOneWidget,
    );
  });

  testWidgets('Kingdom life follows completed Orientation', (tester) async {
    final repository = OrientationProgressRepository(
      read: (_) async => null,
      write: (_, _) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orientationProgressRepositoryProvider.overrideWith(
            (ref) => repository,
          ),
          orientationJourneyStatusProvider.overrideWith(
            (ref) async => const OrientationJourneyStatus(
              completedCount: 3,
              firstIncompleteId: '03-make-room-to-listen',
              started: true,
              complete: false,
            ),
          ),
        ],
        child: const MaterialApp(home: KingdomCourseScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Begin with Orientation'), findsOneWidget);
    expect(
      find.byKey(const Key('kingdom-nugget-01-the-old-life')),
      findsNothing,
    );
  });
}
