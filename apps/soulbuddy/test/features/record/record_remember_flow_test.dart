import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_theme.dart';
import 'package:soulbuddy/features/persons/providers/person_providers.dart';
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

import '../../helpers/in_memory_encounter_repository.dart';
import '../../helpers/audio_player_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installAudioPlayerMocks);
  for (final mode in RecordStartMode.values) {
    testWidgets('${mode.name} opens capture without a text form or live mic', (
      tester,
    ) async {
      final fixture = _RecordFixture();
      addTearDown(fixture.close);
      await tester.pumpWidget(
        fixture.wrap(RecordScreen(startMode: mode)),
      );
      await _settle(tester);

      expect(find.text('Start recording'), findsOneWidget);
      expect(find.text('Write'), findsNothing);
      expect(find.text('Write instead'), findsNothing);
      expect(find.byKey(const Key('encounter-body')), findsNothing);
      expect(fixture.recorder.permissionRequests, 0);
    });
  }

  testWidgets('records and saves audio without requiring any typing', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    Encounter? opened;
    await tester.pumpWidget(
      fixture.wrap(RecordScreen(onMemorySaved: (value) => opened = value)),
    );
    await _settle(tester);
    await _recordAndContinue(tester);

    expect(find.text('Memory type'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Promise'), findsOneWidget);
    expect(find.byKey(const Key('encounter-body')), findsNothing);
    final title = tester.widget<TextFormField>(
      find.byKey(const Key('encounter-title')),
    );
    expect(title.controller!.text, isEmpty);
    await _saveForm(tester);

    final draft = fixture.repository.lastDraft!;
    expect(draft.title, startsWith('Voice memory ·'));
    expect(draft.body, isEmpty);
    expect(draft.audio!.temporaryKey, '/private/take.m4a');
    expect(opened?.id, 'encounter-1');
  });

  testWidgets('system Back closes capture once without requesting the mic', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    var closed = 0;
    await tester.pumpWidget(
      fixture.wrap(RecordScreen(onCancel: () => closed++)),
    );
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(closed, 1);
    expect(fixture.recorder.permissionRequests, 0);
  });

  testWidgets('audio capture preserves person, date, title, and privacy', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    await tester.pumpWidget(
      fixture.wrap(
        RecordScreen(
          startMode: RecordStartMode.person,
          initialPersonIds: const ['person-1'],
          initialDate: DateTime(2020, 5, 4),
          initialTitle: 'A prayer for my father',
          privateReflection: true,
          onMemorySaved: (_) {},
        ),
      ),
    );
    await _settle(tester);
    await _recordAndContinue(tester);

    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Person')).selected,
      isTrue,
    );
    // Clearing an optional title still retains a useful context-based title.
    await tester.enterText(find.byKey(const Key('encounter-title')), '');
    await _saveForm(tester);

    final draft = fixture.repository.lastDraft!;
    expect(draft.memoryType, MemoryType.person);
    expect(draft.personIds, ['person-1']);
    expect(draft.occurredOn, '2020-05-04');
    expect(draft.title, 'A prayer for my father');
    expect(draft.sensitive, isTrue);
    expect(draft.recallEnabled, isFalse);
  });

  testWidgets('guided reflections record immediately and remain private', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    await tester.pumpWidget(
      fixture.wrap(
        RecordScreen(
          startMode: RecordStartMode.reflection,
          initialTitle: 'Reflection · Forgiveness',
          initialBodyPrompt: 'Who is God inviting me to forgive?',
          privateReflection: true,
          onMemorySaved: (_) {},
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Record reflection'), findsOneWidget);
    await _recordAndContinue(tester);
    await _saveForm(tester);
    expect(fixture.repository.lastDraft!.title, 'Reflection · Forgiveness');
    expect(fixture.repository.lastDraft!.sensitive, isTrue);
    expect(fixture.repository.lastDraft!.recallEnabled, isFalse);
    expect(fixture.repository.lastDraft!.body, isEmpty);
  });

  testWidgets('existing body survives without a long-form editor', (
    tester,
  ) async {
    EncounterDraft? saved;
    final audio = _audioDraft();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              initialTitle: 'An older memory',
              initialBody: 'The existing words remain unchanged.',
              audio: audio,
              onCancel: () {},
              onSave: (draft) async => saved = draft,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('encounter-body')), findsNothing);
    await _saveForm(tester);
    expect(saved!.body, 'The existing words remain unchanged.');
    expect(saved!.audio, same(audio));
  });

  testWidgets('a new memory cannot be saved with only a title', (tester) async {
    var saves = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              initialTitle: 'A title alone',
              onCancel: () {},
              onSave: (_) async { saves++; },
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('encounter-body')), findsNothing);
    expect(find.text('Record audio'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('encounter-save'))).onPressed,
      isNull,
    );
    expect(saves, 0);
  });

  testWidgets('failed save keeps the original take for a successful retry', (
    tester,
  ) async {
    final audio = _audioDraft();
    final attempts = <MemoryAudioDraft?>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EncounterForm(
              audio: audio,
              onCancel: () {},
              onSave: (draft) async {
                attempts.add(draft.audio);
                if (attempts.length == 1) throw StateError('disk');
              },
            ),
          ),
        ),
      ),
    );
    await _saveForm(tester);
    expect(find.text('Recording kept. Try saving again.'), findsOneWidget);
    await _saveForm(tester);
    expect(attempts.length, 2);
    expect(attempts.every((value) => identical(value, audio)), isTrue);
  });

  testWidgets('storage loading and failure do not release a transferred take', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    final pending = Completer<InMemoryEncounterRepository>();
    final store = _DiscardTrackingAudioStore();
    await tester.pumpWidget(
      fixture.wrap(
        Consumer(builder: (context, ref, _) {
          ref.watch(encounterRepositoryProvider);
          return const RecordScreen();
        }),
        loadRepository: () => pending.future,
        audioStore: store,
      ),
    );
    await _settle(tester);
    await _recordAndContinue(tester);
    expect(find.byKey(const Key('encounter-title')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Discard recording?'), findsOneWidget);
    await tester.tap(find.text('Keep recording'));
    await _settle(tester);
    expect(store.discarded, isEmpty);

    pending.completeError(StateError('storage unavailable'));
    await _settle(tester);
    expect(find.byKey(const Key('encounter-title')), findsOneWidget);
    expect(find.textContaining('Recording ·'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(store.discarded, ['/private/take.m4a']);
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('storage initialization can retry without recording again', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    var attempts = 0;
    Encounter? saved;
    await tester.pumpWidget(
      fixture.wrap(
        RecordScreen(onMemorySaved: (memory) => saved = memory),
        loadRepository: () async {
          if (++attempts == 1) throw StateError('storage unavailable');
          return fixture.repository;
        },
      ),
    );
    await _settle(tester);
    await _recordAndContinue(tester);
    await _saveForm(tester);
    expect(find.text('Recording kept. Try saving again.'), findsOneWidget);
    expect(saved, isNull);
    await _saveForm(tester);
    expect(saved, isNotNull);
    expect(attempts, 2);
    expect(fixture.recorder.permissionRequests, 1);
    expect(fixture.repository.lastDraft!.audio!.temporaryKey, '/private/take.m4a');
  });

  testWidgets('empty Remember offers one recording action', (tester) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    await tester.pumpWidget(fixture.wrap(const RememberScreen()));
    await _settle(tester);
    expect(find.byKey(const Key('remember-incised-mark')), findsOneWidget);
    expect(find.byKey(const Key('remember-speak')), findsOneWidget);
    expect(find.byKey(const Key('remember-write')), findsNothing);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('empty Remember recording action fits above shell navigation', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      fixture.wrap(
        const RememberScreen(),
        navigation: NavigationBar(
          key: const Key('test-shell-navigation'),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.history), label: 'Remember'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(
      tester.getBottomLeft(find.byKey(const Key('remember-speak'))).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('test-shell-navigation'))).dy,
      ),
    );
    expect(find.byKey(const Key('remember-speak')).hitTestable(), findsOneWidget);
  });

  testWidgets('audio metadata remains accessible at large text sizes', (
    tester,
  ) async {
    final fixture = _RecordFixture();
    addTearDown(fixture.close);
    await tester.pumpWidget(
      fixture.wrap(const RecordScreen(), largeText: true),
    );
    await _settle(tester);
    await _recordAndContinue(tester);
    expect(find.byKey(const Key('encounter-body')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('encounter-title')));
    expect(find.text('Title (optional)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('encounter-date')));
    expect(tester.takeException(), isNull);
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


}

MemoryAudioDraft _audioDraft() => MemoryAudioDraft(
  temporaryKey: '/private/take.m4a',
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 2),
  waveform: const [0.2, 0.8],
);

Future<void> _recordAndContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start recording'));
  await tester.tap(find.text('Start recording'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Stop'));
  await tester.tap(find.text('Stop'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Use recording'));
  await tester.tap(find.text('Use recording'));
  await _settle(tester);
}

Future<void> _saveForm(WidgetTester tester) async {
  final save = find.byKey(const Key('encounter-save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await _settle(tester);
}

class _RecordFixture {
  final repository = InMemoryEncounterRepository();
  final recorder = _RecordFlowRecorder();
  late final controller = AudioCaptureController(
    recorder: recorder,
    allocateTemporary: () async =>
        const TemporaryAudio(key: 'take', locator: '/private/take.m4a'),
  );

  Widget wrap(
    Widget child, {
    Widget? navigation,
    bool largeText = false,
    Future<InMemoryEncounterRepository> Function()? loadRepository,
    AudioAssetStore? audioStore,
  }) =>
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          encounterRepositoryProvider.overrideWith(
            (ref) async => loadRepository == null
                ? repository
                : await loadRepository(),
          ),
          audioCaptureControllerProvider.overrideWith((ref) async => controller),
          prayerPeopleProvider.overrideWith((ref) => Stream.value(const [])),
          if (audioStore != null)
            audioAssetStoreProvider.overrideWith((ref) async => audioStore),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: largeText
              ? (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: child!,
                )
              : null,
          home: Scaffold(body: child, bottomNavigationBar: navigation),
        ),
      );

  Future<void> close() async {
    await controller.close();
    await repository.close();
  }
}

class _DiscardTrackingAudioStore implements AudioAssetStore {
  final discarded = <String>[];

  @override
  Future<void> discardTemporary(String locator) async {
    discarded.add(locator);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordFlowRecorder implements AudioRecorderGateway {
  final _amplitudes = StreamController<double>.broadcast();
  int permissionRequests = 0;

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
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

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
