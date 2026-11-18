import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/persons/data/person_prayer_audio_repository.dart';
import 'package:soulbuddy/features/persons/presentation/person_prayer_audio_section.dart';
import 'package:soulbuddy/features/persons/providers/person_prayer_audio_providers.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

class Recorder implements AudioRecorderGateway {
  final events = StreamController<double>.broadcast();
  @override
  Stream<double> get amplitudes => events.stream;
  @override
  bool get canPause => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(TemporaryAudio temporary) async {}
  @override
  Future<AudioRecorderResult> stop() async => const AudioRecorderResult(
    locator: '/tmp/take.m4a',
    mimeType: 'audio/mp4',
  );
  @override
  Future<void> cancel() async {}
  @override
  Future<void> discard(AudioRecorderResult result) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() => events.close();
}

class Store implements AudioAssetStore {
  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async => CommittedAudio(storageKey: 'audio/$assetId.m4a', byteSize: 100);
  @override
  Future<void> delete(String storageKey) async {}
  @override
  Future<void> discardTemporary(String locator) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('keeps a recorded take available after save failure', (
    tester,
  ) async {
    final store = Store();
    var attempts = 0;
    String? stored;
    final repo = PersonPrayerAudioRepository(
      read: () async => stored,
      write: (value) async {
        attempts++;
        if (attempts == 1) throw StateError('failed');
        stored = value;
      },
      store: store,
      newId: () => 'take$attempts',
    );
    final controller = AudioCaptureController(
      recorder: Recorder(),
      allocateTemporary: () async =>
          const TemporaryAudio(key: 'take', locator: '/tmp/take.m4a'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioAssetStoreProvider.overrideWith((ref) async => store),
          audioCaptureControllerProvider.overrideWith(
            (ref) async => controller,
          ),
          personPrayerAudioRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPersonPrayerRecording(context, 'person1'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.tap(find.text('Start recording'));
    await tester.pump();
    await tester.ensureVisible(find.text('Stop'));
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Use recording'));
    await tester.tap(find.text('Use recording'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Could not save the recording. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 2);
    expect((await repo.load('person1'))?.storageKey, isNotNull);
    expect(find.text('Could not save the recording. Try again.'), findsNothing);
  });
}
