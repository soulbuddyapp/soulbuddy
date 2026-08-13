import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/presentation/encounter_form.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';
import 'package:soulbuddy/features/remember/presentation/memory_detail_screen.dart';

import '../../helpers/in_memory_encounter_repository.dart';

void main() {
  testWidgets('Record begins with equal Speak and Write paths', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordScreen())),
      ),
    );
    await _settle(tester);

    expect(find.text('Keep what you do not want to forget.'), findsOneWidget);
    expect(find.byKey(const Key('record-speak')), findsOneWidget);
    expect(find.byKey(const Key('record-write')), findsOneWidget);
    expect(find.text('Encounter'), findsNothing);

    await tester.tap(find.byKey(const Key('record-write')));
    await _settle(tester);
    expect(find.text('Encounter'), findsOneWidget);
    expect(find.textContaining('Coming'), findsNothing);
  });

  testWidgets(
    'Speak records, reviews, and saves without requiring typed body',
    (tester) async {
      final repository = InMemoryEncounterRepository();
      final recorder = _RecordFlowRecorder();
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
      );
      addTearDown(() async {
        await controller.close();
        await repository.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            encounterRepositoryProvider.overrideWith((ref) async => repository),
            audioCaptureControllerProvider.overrideWith(
              (ref) async => controller,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RecordScreen())),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('record-speak')));
      await _settle(tester);
      await tester.tap(find.text('Start recording'));
      await _settle(tester);
      await tester.tap(find.text('Stop'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      expect(find.text('What kind of memory is this?'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Promise'), findsOneWidget);
      final titleField = tester.widget<TextFormField>(
        find.byKey(const Key('encounter-title')),
      );
      expect(titleField.controller!.text, startsWith('Voice memory ·'));
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(repository.lastDraft!.audio, isNotNull);
      expect(repository.lastDraft!.body, isEmpty);
      expect(find.text('Record saved'), findsOneWidget);
    },
  );

  testWidgets('failed voice save keeps the take and offers a retry', (
    tester,
  ) async {
    var attempts = 0;
    final audio = MemoryAudioDraft(
      temporaryKey: '/private/take.m4a',
      mimeType: 'audio/mp4',
      duration: const Duration(seconds: 2),
      waveform: const [0.2, 0.8],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncounterForm(
            initialTitle: 'Voice memory · 13 Aug',
            audio: audio,
            onCancel: () {},
            onSave: (_) async {
              attempts++;
              throw StateError('disk');
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(attempts, 1);
    expect(
      find.text('The recording is still here. Try saving again or discard it.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    expect(find.text('Save').hitTestable(), findsOneWidget);
  });

  testWidgets('gives an empty Remember screen one quiet incised mark', (
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

    expect(find.byKey(const Key('remember-living-vine')), findsNothing);
    expect(find.byKey(const Key('remember-incised-mark')), findsOneWidget);
    expect(find.text('Record something'), findsOneWidget);
  });

  testWidgets('empty Remember action fits above shell navigation', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: const RememberScreen(),
            bottomNavigationBar: NavigationBar(
              key: const Key('test-shell-navigation'),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  label: 'Remember',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      tester.getBottomLeft(find.text('Record something')).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('test-shell-navigation'))).dy,
      ),
    );
    expect(find.text('Record something').hitTestable(), findsOneWidget);
  });

  testWidgets('records an encounter and shows it in Remember immediately', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await repository.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const SoulBuddyApp(),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Record').last);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('record-write')));
    await _settle(tester);
    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'A prayer was answered',
    );
    await tester.enterText(
      find.byKey(const Key('encounter-body')),
      'Help came through a person.',
    );
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Keep this as an Altar'),
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester);

    await tester.tap(find.text('Remember').last);
    await _settle(tester);

    expect(find.text('A prayer was answered'), findsOneWidget);
    expect(find.text('Help came through a person.'), findsOneWidget);
    expect(find.text('Altar'), findsOneWidget);
  });

  testWidgets('keeps guided choices accessible at large text sizes', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: RecordScreen()),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const Key('record-write')));
    await _settle(tester);

    for (final label in [
      'Encounter',
      'Promise',
      'What I left behind',
      'Revelation',
      'Scripture',
      'Person',
      'Family',
      'Lesson',
      'Testimony',
    ]) {
      final target = find.byKey(Key('record-choice-${label.toLowerCase()}'));
      expect(target, findsOneWidget);
    }

    await tester.tap(find.text('Encounter'));
    await _settle(tester);

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('What happened? (optional)'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(
      find.text('Mark an encounter you want to return to and remember.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every Record choice opens a working typed form', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordScreen())),
      ),
    );
    await _settle(tester);

    for (final label in ['Promise', 'What I left behind', 'Revelation']) {
      await tester.tap(find.byKey(const Key('record-write')));
      await _settle(tester);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(find.text('Record $label'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      if (label == 'What I left behind') {
        final sensitive = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Sensitive'),
        );
        expect(sensitive.value, isTrue);
      }
      await tester.tap(find.text('Record').first);
      await _settle(tester);
    }
    expect(find.textContaining('Coming'), findsNothing);
  });

  testWidgets('Remember filters records and masks sensitive excerpts', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await repository.create(
      const EncounterDraft(
        title: 'A private freedom',
        body: 'A sensitive detail',
        occurredOn: '2026-08-12',
        isAltar: false,
        memoryType: MemoryType.leftBehind,
        sensitive: true,
      ),
    );
    await repository.create(
      const EncounterDraft(
        title: 'A promise to remember',
        body: 'Return to prayer.',
        occurredOn: '2026-08-12',
        isAltar: true,
        memoryType: MemoryType.promise,
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

    expect(find.text('Private memory'), findsOneWidget);
    expect(find.byKey(const Key('remember-living-vine')), findsNothing);
    expect(find.byKey(const Key('remember-incised-mark')), findsOneWidget);
    expect(find.byKey(const Key('promise-paired-slab-mark')), findsOneWidget);
    expect(find.text('A sensitive detail'), findsNothing);
    expect(find.text('A private freedom'), findsNothing);
    await tester.enterText(find.byKey(const Key('remember-search')), 'promise');
    await _settle(tester);
    expect(find.text('A promise to remember'), findsOneWidget);
    expect(find.text('A private freedom'), findsNothing);
  });

  testWidgets('adds dated understanding without rewriting the memory', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository(
      now: () => DateTime.utc(2026, 8, 12, 12),
    );
    addTearDown(repository.close);
    final memory = await repository.create(
      const EncounterDraft(
        title: 'An encounter to understand',
        body: 'The original record.',
        occurredOn: '2026-08-11',
        isAltar: true,
        memoryType: MemoryType.revelation,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(home: MemoryDetailScreen(memoryId: memory.id)),
      ),
    );
    await _settle(tester);
    await tester.enterText(
      find.byKey(const Key('memory-reflection-body')),
      'I understand more about patience now.',
    );
    await tester.tap(find.text('Save reflection'));
    await _settle(tester);

    expect(find.text('I understand more about patience now.'), findsOneWidget);
    expect(find.text('The original record.'), findsOneWidget);
  });
}

class _RecordFlowRecorder implements AudioRecorderGateway {
  final _amplitudes = StreamController<double>.broadcast();

  @override
  Stream<double> get amplitudes => _amplitudes.stream;

  @override
  bool get canPause => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> discard(AudioRecorderResult result) async {}

  @override
  Future<void> dispose() => _amplitudes.close();

  @override
  Future<void> pause() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(TemporaryAudio temporary) async {}

  @override
  Future<AudioRecorderResult> stop() async => const AudioRecorderResult(
    locator: '/private/take.m4a',
    mimeType: 'audio/mp4',
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
