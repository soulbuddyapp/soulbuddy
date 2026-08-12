import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';
import 'package:soulbuddy/features/remember/presentation/memory_detail_screen.dart';

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
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
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

    for (final label in [
      'Encounter',
      'Promise',
      'What I left behind',
      'Revelation',
      'Scripture',
      'Person',
      'Family',
      'Lesson',
      'Testimony',
    ]) {
      final target = find.byKey(Key('record-choice-${label.toLowerCase()}'));
      expect(target, findsOneWidget);
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

  testWidgets('every Record choice opens a working typed form', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordScreen())),
      ),
    );
    await _settle(tester);

    for (final label in ['Promise', 'What I left behind', 'Revelation']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(find.text('Record $label'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      if (label == 'What I left behind') {
        final sensitive = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Sensitive'),
        );
        expect(sensitive.value, isTrue);
      }
      await tester.tap(find.text('Record').first);
      await _settle(tester);
    }
    expect(find.textContaining('Coming'), findsNothing);
  });

  testWidgets('Remember filters records and masks sensitive excerpts', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await repository.create(
      const EncounterDraft(
        title: 'A private freedom',
        body: 'A sensitive detail',
        occurredOn: '2026-08-12',
        isAltar: false,
        memoryType: MemoryType.leftBehind,
        sensitive: true,
      ),
    );
    await repository.create(
      const EncounterDraft(
        title: 'A promise to remember',
        body: 'Return to prayer.',
        occurredOn: '2026-08-12',
        isAltar: true,
        memoryType: MemoryType.promise,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RememberScreen())),
      ),
    );
    await _settle(tester);

    expect(find.text('Sensitive memory'), findsOneWidget);
    expect(find.text('A sensitive detail'), findsNothing);
    await tester.enterText(find.byKey(const Key('remember-search')), 'promise');
    await _settle(tester);
    expect(find.text('A promise to remember'), findsOneWidget);
    expect(find.text('A private freedom'), findsNothing);
  });

  testWidgets('adds dated understanding without rewriting the memory', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 12, 12),
    );
    addTearDown(repository.close);
    final memory = await repository.create(
      const EncounterDraft(
        title: 'An encounter to understand',
        body: 'The original record.',
        occurredOn: '2026-08-11',
        isAltar: true,
        memoryType: MemoryType.revelation,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(home: MemoryDetailScreen(memoryId: memory.id)),
      ),
    );
    await _settle(tester);
    await tester.enterText(
      find.byKey(const Key('memory-reflection-body')),
      'I understand more about patience now.',
    );
    await tester.tap(find.text('Save reflection'));
    await _settle(tester);

    expect(find.text('I understand more about patience now.'), findsOneWidget);
    expect(find.text('The original record.'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
