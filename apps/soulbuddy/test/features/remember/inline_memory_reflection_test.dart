import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/remember/presentation/inline_memory_reflection.dart';

import '../../helpers/in_memory_encounter_repository.dart';
import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets('written reflection remains attached to its memory', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final memory = await repository.create(
      const EncounterDraft(
        title: 'Memory',
        body: 'Words',
        occurredOn: '2026-11-03',
        isAltar: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          speechRecognizerProvider.overrideWithValue(NoSpeech()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InlineMemoryReflection(
              memory: memory,
              localDate: '2026-11-03',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Write reflection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'I am grateful.');
    await tester.pump();
    await tester.tap(find.text('Save reflection'));
    await tester.pumpAndSettle();
    final reflections = await repository.watchReflections(memory.id).first;
    expect(reflections.single.body, 'I am grateful.');
    expect(reflections.single.encounterId, memory.id);
  });
}
