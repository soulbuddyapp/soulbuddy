import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/remember/domain/daily_memory.dart';
import 'package:soulbuddy/features/remember/presentation/daily_remembrance_card.dart';

void main() {
  testWidgets('shows a quiet option-led remembrance without gamification', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: DailyRemembranceCard(dailyMemory: _daily()),
            ),
          ),
        ),
        GoRoute(
          path: '/remember/daily/:date',
          builder: (_, _) => const Scaffold(body: Text('Recall focus')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remember today'), findsOneWidget);
    expect(find.text('A promise before God'), findsOneWidget);
    expect(find.text('Return to this'), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    expect(find.textContaining('streak', findRichText: true), findsNothing);
    expect(find.textContaining('score', findRichText: true), findsNothing);
    expect(find.textContaining('failed', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const Key('daily-memory-open')));
    await tester.pumpAndSettle();
    expect(find.text('Recall focus'), findsOneWidget);
  });
}

DailyMemory _daily() => DailyMemory(
  occurrenceId: 'occurrence-1',
  localDate: DateTime(2026, 8, 12),
  status: DailyMemoryStatus.active,
  memory: Encounter(
    id: 'memory-1',
    ownerId: 'owner-1',
    title: 'Return to morning prayer',
    body: 'I promised to begin the day before God.',
    occurredOn: '2026-08-01',
    isAltar: true,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
    currentRevisionId: 'revision-1',
    syncState: EncounterSyncState.synced,
    memoryType: MemoryType.promise,
  ),
);
