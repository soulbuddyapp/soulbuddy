import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';

import '../../helpers/in_memory_encounter_repository.dart';

void main() {
  testWidgets('records an encounter and shows it in Remember immediately', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Record').last);
    await _settle(tester);
    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'A prayer was answered',
    );
    await tester.enterText(
      find.byKey(const Key('encounter-body')),
      'Help came through a person.',
    );
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.ensureVisible(find.text('Save encounter'));
    await tester.pump();
    await tester.tap(find.text('Save encounter'));
    await _settle(tester);

    await tester.tap(find.text('Remember').last);
    await _settle(tester);

    expect(find.text('A prayer was answered'), findsOneWidget);
    expect(find.text('Help came through a person.'), findsOneWidget);
    expect(find.text('Altar'), findsOneWidget);
  });

  testWidgets('keeps guided choices accessible at large text sizes', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: RecordScreen()),
        ),
      ),
    );
    await _settle(tester);

    for (final label in ['Encounter', 'Lesson', 'Commitment', 'Prayer']) {
      final target = find.byKey(Key('record-choice-${label.toLowerCase()}'));
      expect(target, findsOneWidget);
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('What happened? (optional)'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(
      find.text('Mark an encounter you want to return to and remember.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
