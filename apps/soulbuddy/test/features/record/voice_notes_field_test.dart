import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/data/voice_note_repository.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';

void main() {
  testWidgets('changing context clears an earlier recording error', (
    tester,
  ) async {
    VoiceNoteContext noteContext = (type: 'goal', id: 'first', field: 'notes');
    late StateSetter update;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceNotesProvider.overrideWith((ref, context) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return VoiceNotesField(
                  noteContext: noteContext,
                  title: 'Notes',
                  beforeRecord: () async => throw StateError('unavailable'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('Recording unavailable'), findsOneWidget);

    update(() => noteContext = (type: 'goal', id: 'second', field: 'notes'));
    await tester.pumpAndSettle();
    expect(find.text('Recording unavailable'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('an in-flight callback stays with its original context', (
    tester,
  ) async {
    final ready = Completer<void>();
    final busy = <String>[];
    VoiceNoteContext noteContext = (type: 'goal', id: 'first', field: 'notes');
    late StateSetter update;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceNotesProvider.overrideWith((ref, context) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final callbackContext = noteContext.id;
                return VoiceNotesField(
                  noteContext: noteContext,
                  title: 'Notes',
                  beforeRecord: () => ready.future,
                  onBusyChanged: (value) => busy.add('$callbackContext:$value'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pump();
    expect(busy, ['first:true']);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    update(() => noteContext = (type: 'goal', id: 'second', field: 'notes'));
    await tester.pump();
    ready.completeError(StateError('old context failed'));
    await tester.pumpAndSettle();

    expect(busy, ['first:true', 'first:false']);
    expect(find.text('Recording unavailable'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
  });
}
