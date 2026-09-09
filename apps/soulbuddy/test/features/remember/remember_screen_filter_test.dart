import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';

void main() {
  testWidgets('filters Memories by Altar and voice without hiding All', (
    tester,
  ) async {
    final memories = [
      _memory('voice', 'Voice memory', altar: false),
      _memory('altar', 'Altar memory', altar: true),
      _memory('plain', 'Written memory', altar: false),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encountersProvider.overrideWith((ref) => Stream.value(memories)),
          memoryAudioForEncounterProvider.overrideWith(
            (ref, encounterId) => Stream.value(
              encounterId == 'voice' ? _audio(encounterId) : null,
            ),
          ),
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) => Future.error(StateError('player unavailable')),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RememberScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Written memory'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Voice memory'), findsOneWidget);
    expect(find.text('Altar memory'), findsOneWidget);
    expect(find.text('Written memory'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('remember-filter-altar')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('remember-filter-altar')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Altar memory'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Voice memory'), findsNothing);
    expect(find.text('Altar memory'), findsOneWidget);
    expect(find.text('Written memory'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('remember-filter-voice')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('remember-filter-voice')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Voice memory'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Voice memory'), findsOneWidget);
    expect(find.text('Altar memory'), findsNothing);
    expect(find.text('Written memory'), findsNothing);
  });
}

Encounter _memory(String id, String title, {required bool altar}) => Encounter(
  id: id,
  ownerId: 'owner-1',
  title: title,
  body: '',
  occurredOn: '2026-09-09',
  isAltar: altar,
  createdAt: DateTime.utc(2026, 9, 9),
  updatedAt: DateTime.utc(2026, 9, 9),
  currentRevisionId: 'revision-$id',
  syncState: EncounterSyncState.synced,
);

MemoryAudio _audio(String encounterId) => MemoryAudio(
  id: 'audio-$encounterId',
  encounterId: encounterId,
  revisionId: 'revision-$encounterId',
  storageKey: 'audio/$encounterId.m4a',
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 5),
  byteSize: 10,
  waveform: const [0.2, 0.7],
  createdAt: DateTime.utc(2026, 9, 9),
);
