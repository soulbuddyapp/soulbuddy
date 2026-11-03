import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/record/presentation/encounter_form.dart';
import 'package:soulbuddy/features/record/presentation/record_screen.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/persons/providers/person_providers.dart';
import 'package:soulbuddy/features/remember/presentation/remember_screen.dart';

import '../../helpers/in_memory_encounter_repository.dart';
import '../../helpers/audio_player_mocks.dart';

void main() {
  testWidgets(
    'date label stays separate from the recording summary and field',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EncounterForm(
                audio: MemoryAudioDraft(
                  temporaryKey: '/take',
                  mimeType: 'audio/mp4',
                  duration: const Duration(seconds: 85),
                  waveform: const [0.3],
                ),
                onCancel: () {},
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('encounter-date')));
      await tester.pump();
      final summary = tester.getRect(find.textContaining('Recording ·'));
      final label = tester.getRect(find.text('Date'));
      final field = tester.getRect(find.byKey(const Key('encounter-date')));
      expect(label.top, greaterThanOrEqualTo(summary.bottom));
      expect(label.bottom, lessThanOrEqualTo(field.top));
    },
  );
  testWidgets('date label remains separate at large text sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: EncounterForm(
              audio: MemoryAudioDraft(
                temporaryKey: '/take',
                mimeType: 'audio/mp4',
                duration: const Duration(seconds: 85),
                waveform: const [0.3],
              ),
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('encounter-date')));
    await tester.pump();
    expect(
      tester.getRect(find.text('Date')).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('encounter-date'))).top,
      ),
    );
    expect(tester.takeException(), isNull);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installAudioPlayerMocks);
  testWidgets('first memory guidance remains expanded until a memory exists', (
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

    expect(find.byKey(const Key('forget-quickly-expanded')), findsOneWidget);
    expect(
      find.textContaining('Miracles happen around us daily'),
      findsOneWidget,
    );
  });

  testWidgets('returning memory guidance is compact and expandable', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    await repository.create(
      const EncounterDraft(
        title: 'The help I received',
        body: 'I remember.',
        occurredOn: '2026-08-30',
        isAltar: false,
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

    expect(find.byKey(const Key('forget-quickly-collapsed')), findsOneWidget);
    expect(find.text('The help I received'), findsOneWidget);
  });

  testWidgets('new memory authoring offers recording and no body editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              memoryType: MemoryType.encounter,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('encounter-body')), findsNothing);
    expect(find.byKey(const Key('encounter-add-audio')), findsOneWidget);
    expect(find.text('Record audio'), findsOneWidget);
  });

  testWidgets('in-form voice capture survives through its handoff', (
    tester,
  ) async {
    final recorder = _CaptureRecorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async => const TemporaryAudio(
        key: '/private/encounter.m4a',
        locator: '/private/encounter.m4a',
      ),
    );
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              memoryType: MemoryType.encounter,
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Record audio'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await _settle(tester);
    expect(find.text('Background sound'), findsOneWidget);
    expect(find.text('Stillness'), findsOneWidget);
    expect(find.text('Flowing water'), findsOneWidget);
    await tester.ensureVisible(find.text('Use recording'));
    await tester.tap(find.text('Use recording'));
    await _settle(tester);

    expect(find.textContaining('Recording ·'), findsOneWidget);
    expect(recorder.closedWhileRecording, isFalse);
  });

  testWidgets('leaving the memory form discards its unsaved recording', (
    tester,
  ) async {
    final store = _DiscardTrackingAudioStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioAssetStoreProvider.overrideWith((ref) async => store)],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              audio: MemoryAudioDraft(
                temporaryKey: '/private/unsaved.m4a',
                mimeType: 'audio/mp4',
                duration: const Duration(seconds: 2),
                waveform: const [0.2, 0.8],
              ),
              onCancel: () {},
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remember'));
    await tester.pumpAndSettle();

    expect(store.discarded, isEmpty);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(store.discarded, ['/private/unsaved.m4a']);
  });

  testWidgets('declining discard retains the unsaved take', (tester) async {
    final store = _DiscardTrackingAudioStore();
    var cancelled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioAssetStoreProvider.overrideWith((ref) async => store)],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              audio: MemoryAudioDraft(
                temporaryKey: '/private/keep.m4a',
                mimeType: 'audio/mp4',
                duration: const Duration(seconds: 2),
                waveform: const [0.2],
              ),
              onCancel: () => cancelled = true,
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Remember'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep recording'));
    await tester.pumpAndSettle();
    expect(store.discarded, isEmpty);
    expect(cancelled, isFalse);
    expect(find.textContaining('Recording ·'), findsOneWidget);
  });

  testWidgets('system Back discards an unsaved encounter recording', (
    tester,
  ) async {
    final store = _DiscardTrackingAudioStore();
    var cancelled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioAssetStoreProvider.overrideWith((ref) async => store)],
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              audio: MemoryAudioDraft(
                temporaryKey: '/private/system-back.m4a',
                mimeType: 'audio/mp4',
                duration: const Duration(seconds: 2),
                waveform: const [0.2, 0.8],
              ),
              onCancel: () => cancelled = true,
              onSave: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(store.discarded, isEmpty);
    expect(cancelled, isFalse);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(store.discarded, ['/private/system-back.m4a']);
    expect(cancelled, isTrue);
  });

  testWidgets('a Person memory opens as Person while remaining editable', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final controller = AudioCaptureController(
      recorder: _CaptureRecorder(),
      allocateTemporary: () async => const TemporaryAudio(
        key: '/private/encounter.m4a',
        locator: '/private/encounter.m4a',
      ),
    );
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureControllerProvider.overrideWith(
            (ref) async => controller,
          ),
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordScreen(
              startMode: RecordStartMode.person,
              initialPersonIds: ['person-1'],
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _captureAndContinue(tester);

    expect(find.text('Keep this recording'), findsOneWidget);
    expect(find.text('Memory type'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Person'))
          .selected,
      isTrue,
    );
  });

  testWidgets('saving opens the exact Memory that was created', (tester) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final controller = AudioCaptureController(
      recorder: _CaptureRecorder(),
      allocateTemporary: () async => const TemporaryAudio(
        key: '/private/encounter.m4a',
        locator: '/private/encounter.m4a',
      ),
    );
    addTearDown(controller.close);
    Encounter? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureControllerProvider.overrideWith(
            (ref) async => controller,
          ),
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RecordScreen(
              startMode: RecordStartMode.write,
              onMemorySaved: (memory) => opened = memory,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _captureAndContinue(tester);

    await tester.enterText(
      find.byKey(const Key('encounter-title')),
      'A Memory I can find',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(opened?.id, 'encounter-1');
    expect(opened?.title, 'A Memory I can find');
    expect(find.text('Memory saved'), findsNothing);
  });

  testWidgets('formation reflections begin private with daily recall off', (
    tester,
  ) async {
    final repository = InMemoryEncounterRepository();
    addTearDown(repository.close);
    final controller = AudioCaptureController(
      recorder: _CaptureRecorder(),
      allocateTemporary: () async => const TemporaryAudio(
        key: '/private/encounter.m4a',
        locator: '/private/encounter.m4a',
      ),
    );
    addTearDown(controller.close);
    const prompt =
        'What is God showing me through this Scripture, and what will I practice?';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureControllerProvider.overrideWith(
            (ref) async => controller,
          ),
          encounterRepositoryProvider.overrideWith((ref) async => repository),
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordScreen(
              startMode: RecordStartMode.write,
              initialBodyPrompt: prompt,
              privateReflection: true,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _captureAndContinue(tester);

    expect(find.byKey(const Key('encounter-body')), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Sensitive'),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Daily remembrance'),
          )
          .value,
      isFalse,
    );
  });
}

Future<void> _captureAndContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start recording'));
  await tester.tap(find.text('Start recording'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Stop'));
  await tester.tap(find.text('Stop'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Use recording'));
  await tester.pump();
  await tester.runAsync(() => tester.tap(find.text('Use recording')));
  final form = find.byKey(const Key('encounter-title'));
  for (var attempt = 0; attempt < 30 && form.evaluate().isEmpty; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    form,
    findsOneWidget,
    reason:
        'Recording handoff did not reach the form. Visible text: '
        '${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _DiscardTrackingAudioStore implements AudioAssetStore {
  final discarded = <String>[];

  @override
  Future<void> discardTemporary(String locator) async {
    discarded.add(locator);
  }

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) => throw UnimplementedError();

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) => throw UnimplementedError();

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String storageKey) => throw UnimplementedError();

  @override
  Future<AudioPlaybackSource?> open(String storageKey) =>
      throw UnimplementedError();
}

class _CaptureRecorder implements AudioRecorderGateway {
  final _amplitudes = StreamController<double>.broadcast();
  bool recording = false;
  bool closedWhileRecording = false;

  @override
  Stream<double> get amplitudes => _amplitudes.stream;

  @override
  bool get canPause => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> start(TemporaryAudio target) async => recording = true;

  @override
  Future<AudioRecorderResult> stop() async {
    recording = false;
    return const AudioRecorderResult(
      locator: '/private/encounter.m4a',
      mimeType: 'audio/mp4',
    );
  }

  @override
  Future<void> cancel() async => recording = false;

  @override
  Future<void> discard(AudioRecorderResult result) async {}

  Future<void> close() async {
    closedWhileRecording = recording;
    recording = false;
    await _amplitudes.close();
  }

  @override
  Future<void> dispose() => close();

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}
