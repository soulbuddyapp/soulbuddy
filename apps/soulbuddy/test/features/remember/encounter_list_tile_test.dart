import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/remember/presentation/encounter_list_tile.dart';

void main() {
  testWidgets('sensitive audio memory hides its title and written excerpt', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioForEncounterProvider.overrideWith(
            (ref, encounterId) => Stream.value(_audio(encounterId)),
          ),
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) => Future.error(StateError('player unavailable')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: EncounterListTile(encounter: _encounter())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private memory'), findsOneWidget);
    expect(find.textContaining('Audio memory'), findsOneWidget);
    expect(find.text('A private title'), findsNothing);
    expect(find.textContaining('private words'), findsNothing);
  });
}

Encounter _encounter() => Encounter(
  id: 'memory-1',
  ownerId: 'owner-1',
  title: 'A private title',
  body: 'These private words must not appear in the list.',
  occurredOn: '2026-08-13',
  isAltar: true,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
  currentRevisionId: 'revision-1',
  syncState: EncounterSyncState.synced,
  memoryType: MemoryType.encounter,
  sensitive: true,
);

MemoryAudio _audio(String encounterId) => MemoryAudio(
  id: 'audio-1',
  encounterId: encounterId,
  revisionId: 'revision-1',
  storageKey: 'audio/private.m4a',
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 7),
  byteSize: 3,
  waveform: const [0.2, 0.7],
  createdAt: DateTime.utc(2026, 8, 13),
);
