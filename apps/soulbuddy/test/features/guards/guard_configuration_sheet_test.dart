import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/core/speech/speech_capture_providers.dart';
import 'package:soulbuddy/features/goals/domain/goal.dart';
import 'package:soulbuddy/features/guards/data/guard_selection_repository.dart';
import 'package:soulbuddy/features/guards/domain/guard_definition.dart';
import 'package:soulbuddy/features/guards/presentation/guard_configuration_sheet.dart';
import 'package:soulbuddy/features/guards/providers/guard_providers.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';

import '../../helpers/no_speech_recognizer.dart';

void main() {
  testWidgets(
    'guard configuration states enforcement truthfully at large text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final goal = _goal();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            goalGuardSelectionsProvider(
              goal.id,
            ).overrideWith((ref) => Stream.value(const <GoalGuardSelection>[])),
            // The private note now offers the microphone, which resolves
            // availability when the editor opens.
            speechRecognizerProvider.overrideWithValue(NoSpeech()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(body: GuardConfigurationSheet(goal: goal)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Close the door'), findsOneWidget);
      final disclosure = find.textContaining('does not verify that a device');
      await tester.scrollUntilVisible(disclosure, 120);
      expect(disclosure, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AdGuard Family Protection'),
        120,
      );
      expect(find.text('AdGuard Family Protection'), findsOneWidget);
      expect(find.text('Review'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guard notes record in context and preserve earlier words', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 3);
    final definition = GuardDefinition(
      id: 'phone-away',
      contentVersion: 1,
      kind: GuardKind.physicalBoundary,
      title: 'Put the phone away',
      description: 'Choose where your phone rests.',
      steps: const ['Choose a place outside the bedroom.'],
      platforms: const {GuardPlatform.physical},
      goalContextTags: const {},
      reviewedAt: now,
    );
    final selection = GoalGuardSelection(
      id: 'selection',
      goalId: 'goal',
      ownerId: 'owner',
      guardDefinitionId: definition.id,
      guardContentVersion: 1,
      configuredAt: now,
      privateNote: 'I placed the charger beside the kitchen door.',
    );
    final repository = _Selections(selection);
    final goal = Goal(
      id: 'goal',
      ownerId: 'owner',
      mode: GoalMode.actionable,
      status: GoalStatus.active,
      currentRevisionId: 'revision',
      position: 0,
      title: 'Quiet evenings',
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guardCatalogueProvider.overrideWithValue([definition]),
          guardSelectionRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          voiceNotesProvider.overrideWith(
            (ref, noteContext) => Stream.value([]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: GuardConfigurationSheet(goal: goal)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review or edit'));
    await tester.pumpAndSettle();

    final field = tester.widget<VoiceNotesField>(
      find.byKey(const Key('guard-private-recording')),
    );
    expect(field.noteContext, (
      type: 'goal',
      id: 'goal',
      field: 'guard:phone-away',
    ));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Earlier note'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('guard-mark-configured')));
    await tester.tap(find.byKey(const Key('guard-mark-configured')));
    await tester.pumpAndSettle();

    expect(repository.savedNote, selection.privateNote);
  });
}

class _Selections implements GuardSelectionRepository {
  _Selections(this.selection);
  final GoalGuardSelection selection;
  String? savedNote;

  @override
  Stream<List<GoalGuardSelection>> watchForGoal(String goalId) =>
      Stream.value([selection]);

  @override
  Future<GoalGuardSelection> select({
    required String goalId,
    required GuardDefinition definition,
    String? privateNote,
  }) async {
    savedNote = privateNote;
    return selection;
  }

  @override
  Future<void> archive(String selectionId) async {}
}

Goal _goal() => Goal(
  id: 'guard-ui-goal',
  ownerId: 'owner-1',
  starterKey: GoalStarterKey.stopControl,
  mode: GoalMode.mixed,
  status: GoalStatus.active,
  currentRevisionId: 'revision-1',
  position: 0,
  title: 'Stop something fighting to control me',
  createdAt: DateTime.utc(2026, 8, 29),
  updatedAt: DateTime.utc(2026, 8, 29),
);
