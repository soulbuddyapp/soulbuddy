import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/presentation/inline_audio_capture.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';
import 'package:soulbuddy/features/record/domain/encounter_draft.dart';
import 'package:soulbuddy/features/record/domain/encounter.dart';
import 'package:soulbuddy/features/record/providers/encounter_providers.dart';
import 'package:soulbuddy/features/record/providers/voice_note_providers.dart';
import 'package:soulbuddy/features/record/presentation/voice_notes_field.dart';
import 'package:soulbuddy/features/record/presentation/inline_memory_recorder.dart';
import 'package:soulbuddy/features/remember/presentation/inline_memory_reflection.dart';
import '../../helpers/in_memory_encounter_repository.dart';

void main() {
  testWidgets('memory recording starts and saves in its original context', (
    tester,
  ) async {
    final repo = InMemoryEncounterRepository();
    final recorder = _Recorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repo),
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlineMemoryRecorder(label: 'Record something'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Record something'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(recorder.starts, 1);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repo.lastDraft?.audio, isNotNull);
    expect((await repo.watchAll().first), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    unawaited(controller.close());
  });
  testWidgets(
    'permission denial can be dismissed without trapping navigation',
    (tester) async {
      final recorder = _Recorder()..permissionGranted = false;
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/take'),
      );
      final busy = <bool>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inlineAudioCaptureControllerProvider.overrideWith(
              (ref, key) async => controller,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: InlineAudioCapture(
                onSave: (_) async {},
                onBusyChanged: busy.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Record'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Microphone access was not granted.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Record'), findsOneWidget);
      expect(busy, [true, false]);
      await tester.pumpWidget(const SizedBox());
      unawaited(controller.close());
    },
  );
  testWidgets('backgrounding pauses the active microphone', (tester) async {
    final recorder = _Recorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: InlineAudioCapture(onSave: (_) async {})),
        ),
      ),
    );
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.state.phase, AudioCapturePhase.paused);
    expect(recorder.pauses, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    unawaited(controller.close());
  });
  testWidgets(
    'a failed context link retries without creating a duplicate recording',
    (tester) async {
      final repo = _FailOnceRepository();
      final recorder = _Recorder();
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/take'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            encounterRepositoryProvider.overrideWith((ref) async => repo),
            voiceNotesProvider.overrideWith((ref, context) => Stream.value([])),
            inlineAudioCaptureControllerProvider.overrideWith(
              (ref, key) async => controller,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VoiceNotesField(
                noteContext: (type: 'prayer', id: 'p1', field: 'reflection'),
                title: 'After prayer',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Record'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Retry save'), findsOneWidget);
      await tester.tap(find.text('Retry save'));
      await tester.pump();
      expect(repo.calls, 2);
      expect(repo.lastDraft?.voiceNoteContext, (
        type: 'prayer',
        id: 'p1',
        field: 'reflection',
      ));
      expect((await repo.watchAll().first), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      unawaited(controller.close());
    },
  );
  testWidgets('inline reflection links the recording to its original memory', (
    tester,
  ) async {
    final repo = InMemoryEncounterRepository();
    final memory = await repo.create(
      const EncounterDraft(
        title: 'Memory',
        body: '',
        occurredOn: '2026-11-03',
        isAltar: false,
      ),
    );
    final recorder = _Recorder();
    final controller = AudioCaptureController(
      recorder: recorder,
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/take'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encounterRepositoryProvider.overrideWith((ref) async => repo),
          inlineAudioCaptureControllerProvider.overrideWith(
            (ref, key) async => controller,
          ),
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
    await tester.tap(find.text('Record reflection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    final reflections = await repo.watchReflections(memory.id).first;
    expect(reflections.single.audioEncounterId, 'encounter-2');
    expect(repo.lastDraft?.audio, isNotNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(controller.close());
  });
  testWidgets(
    'first tap starts capture inline and stopping permits saving without playback',
    (tester) async {
      final recorder = _Recorder();
      final controller = AudioCaptureController(
        recorder: recorder,
        allocateTemporary: () async =>
            const TemporaryAudio(key: 'take', locator: '/take'),
      );
      var saved = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inlineAudioCaptureControllerProvider.overrideWith(
              (ref, key) async => controller,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: InlineAudioCapture(
                onSave: (_) async {
                  saved = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Record'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(recorder.starts, 1);
      expect(find.byKey(const Key('audio-live-level')), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, isTrue);
      await tester.pumpWidget(const SizedBox());
      unawaited(controller.close());
    },
  );
}

class _FailOnceRepository extends InMemoryEncounterRepository {
  int calls = 0;
  @override
  Future<Encounter> create(EncounterDraft draft) async {
    calls++;
    if (calls == 1) throw StateError('save failed');
    return super.create(draft);
  }
}

class _Recorder implements AudioRecorderGateway {
  final levels = StreamController<double>.broadcast();
  int starts = 0;
  int pauses = 0;
  bool permissionGranted = true;
  @override
  Stream<double> get amplitudes => levels.stream;
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => permissionGranted;
  @override
  Future<void> start(TemporaryAudio temporary) async {
    starts++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {}
  @override
  Future<AudioRecorderResult> stop() async =>
      const AudioRecorderResult(locator: '/take', mimeType: 'audio/mp4');
  @override
  Future<void> cancel() async {}
  @override
  Future<void> discard(AudioRecorderResult result) async {}
  @override
  Future<void> dispose() async {}
}
