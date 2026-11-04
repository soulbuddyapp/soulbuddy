import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/remember/presentation/memory_detail_screen.dart';

import '../../helpers/in_memory_encounter_repository.dart';
import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets('saved Memory shows and can change its Altar state', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final memory = await repository.create(
      const EncounterDraft(
        title: 'A prayer answered',
        body: 'I want to remember this.',
        occurredOn: '2026-09-09',
        isAltar: true,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          // The reflection field now offers the microphone, which resolves
          // availability on mount.
          speechRecognizerProvider.overrideWithValue(NoSpeech()),
        ],
        child: MaterialApp(home: MemoryDetailScreen(memoryId: memory.id)),
      ),
    );
    await _settle(tester);

    expect(find.text('At my Altar'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('memory-altar-status')))
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('memory-altar-status')));
    await _settle(tester);
    expect(find.text('Keep at my Altar'), findsOneWidget);
    expect(find.text('Archive Memory'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
