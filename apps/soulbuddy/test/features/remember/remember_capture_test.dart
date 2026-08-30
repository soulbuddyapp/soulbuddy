import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/record/presentation/encounter_form.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';

import '../../helpers/in_memory_encounter_repository.dart';

void main() {
  testWidgets('first memory guidance remains expanded until a memory exists', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RememberScreen())),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const Key('forget-quickly-expanded')), findsOneWidget);
    expect(
      find.textContaining('Miracles happen around us daily'),
      findsOneWidget,
    );
  });

  testWidgets('returning memory guidance is compact and expandable', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await repository.create(
      const EncounterDraft(
        title: 'The help I received',
        body: 'I remember.',
        occurredOn: '2026-08-30',
        isAltar: false,
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

    expect(find.byKey(const Key('forget-quickly-collapsed')), findsOneWidget);
    expect(find.text('The help I received'), findsOneWidget);
  });

  testWidgets('What happened always offers a voice recording', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              memoryType: MemoryType.encounter,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('encounter-body')), findsOneWidget);
    expect(find.byKey(const Key('encounter-add-audio')), findsOneWidget);
    expect(find.text('Record what happened'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
