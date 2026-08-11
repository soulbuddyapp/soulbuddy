import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_providers.dart';

import '../helpers/in_memory_encounter_repository.dart';
import '../helpers/in_memory_prayer_repository.dart';

void main() {
  testWidgets('shows all five top-level destinations', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const SoulBuddyApp(),
      ),
    );

    for (final label in ['Today', 'Prayers', 'Record', 'Remember', 'Circles']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Remember').last);
    await tester.pumpAndSettle();

    expect(find.text('What you have recorded'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opens personalized prayer creation from the library choice', (
    tester,
  ) async {
    final encounters = InMemoryEncounterRepository();
    final prayers = InMemoryPrayerRepository(prayers: const []);
    addTearDown(encounters.close);
    addTearDown(prayers.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => encounters),
          prayerRepositoryProvider.overrideWith((ref) async => prayers),
        ],
        child: const SoulBuddyApp(),
      ),
    );

    await tester.tap(find.text('Prayers').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create personalized'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a prayer style'), findsOneWidget);
    expect(find.text('Daily / affirming'), findsOneWidget);
  });
}
