import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';

import '../helpers/in_memory_encounter_repository.dart';

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
}
