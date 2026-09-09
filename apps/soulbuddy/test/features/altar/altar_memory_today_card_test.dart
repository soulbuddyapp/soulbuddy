import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/altar/presentation/altar_today_card.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';

void main() {
  testWidgets('Altar Memory card opens the exact saved Memory', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioForEncounterProvider.overrideWith(
            (ref, encounterId) => Stream.value(null),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AltarMemoryTodayCard(
              memory: _memory(),
              onOpen: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('At your Altar'), findsOneWidget);
    expect(find.text('A Memory kept close'), findsOneWidget);
    await tester.tap(find.text('Open Memory'));
    expect(opened, isTrue);
  });
}

Encounter _memory() => Encounter(
  id: 'memory-1',
  ownerId: 'owner-1',
  title: 'A Memory kept close',
  body: '',
  occurredOn: '2026-09-09',
  isAltar: true,
  createdAt: DateTime.utc(2026, 9, 9),
  updatedAt: DateTime.utc(2026, 9, 9),
  currentRevisionId: 'revision-1',
  syncState: EncounterSyncState.synced,
);
