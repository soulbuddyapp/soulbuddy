import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/spiritual_session_providers.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_deletion.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/application/memory_soundscape_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/data/memory_soundscape_preferences.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_soundscape.dart';
import 'package:soulbuddy/features/record/audio/presentation/audio_playback_control.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

void main() {
  testWidgets('compact playback is explicit and never autoplays', (
    tester,
  ) async {
    final driver = _ControlDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _ControlAssetStore(),
      driver: driver,
    );
    final sessionController = SpiritualSessionController();
    final soundscapePlayer = _SilentSoundscapePlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(
            sessionController,
          ),
          memorySoundscapePreferencesProvider.overrideWith(
            (ref) => MemorySoundscapePreferences(
              read: (_) async => '{"soundscape":"flowingWater","volume":0.15}',
              write: (_, _) async {},
            ),
          ),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) =>
                MemorySoundscapePlaybackCoordinator(player: soundscapePlayer),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioPlaybackControl(
              audio: _audio(),
              compact: true,
              label: 'Audio memory',
              playLabel: 'Listen',
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Audio memory'), findsOneWidget);
    expect(find.text('00:07'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(driver.events, isEmpty);

    await tester.tap(find.text('Listen'));
    await _settle(tester);
    expect(driver.events, ['play']);
    expect(find.text('Pause'), findsOneWidget);
    expect(sessionController.state.session?.id, 'memory:audio-1');
    expect(sessionController.state.session?.kind, SpiritualSessionKind.memory);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(driver.events, ['play']);
    expect(soundscapePlayer.events, ['start:flowingWater']);
    driver.emitPosition(const Duration(seconds: 3));
    await tester.pump();
    expect(sessionController.state.position, const Duration(seconds: 3));
    driver.emitStatus(MemoryAudioDriverStatus.completed);
    await tester.pump();
    expect(sessionController.state.session, isNull);
    expect(soundscapePlayer.events, ['start:flowingWater', 'stop']);
  });

  testWidgets('deletion names irreversibility and leaves no ambiguous action', (
    tester,
  ) async {
    final events = <String>[];
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _ControlAssetStore(),
      driver: _ControlDriver(),
    );
    final deletion = MemoryAudioDeletion(
      repository: _ControlRepository(events),
      assetStore: _DeletionControlStore(events),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          memoryAudioDeletionProvider.overrideWith((ref) async => deletion),
          memorySoundscapePreferencesProvider.overrideWith(
            (ref) => MemorySoundscapePreferences(
              read: (_) async => null,
              write: (_, _) async {},
            ),
          ),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) => MemorySoundscapePlaybackCoordinator(
              player: _SilentSoundscapePlayer(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioPlaybackControl(audio: _audio(), allowDelete: true),
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Delete audio'));
    await _settle(tester);
    expect(
      find.text(
        'This audio cannot be recovered from SoulBuddy. The written memory will remain.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove audio'));
    await _settle(tester);

    expect(events, ['metadata:memory-1', 'bytes:audio/memory.m4a']);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resume after navigation uses the latest sound selection', (
    tester,
  ) async {
    final values = <String, String>{};
    final preferences = MemorySoundscapePreferences(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    await preferences.save(
      'audio-1',
      const MemorySoundscapeSettings(
        soundscape: MemorySoundscape.flowingWater,
        volume: .15,
      ),
    );
    final driver = _ControlDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _ControlAssetStore(),
      driver: driver,
    );
    final sessionController = SpiritualSessionController();
    final soundscapePlayer = _SilentSoundscapePlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(
            sessionController,
          ),
          memorySoundscapePreferencesProvider.overrideWithValue(preferences),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) =>
                MemorySoundscapePlaybackCoordinator(player: soundscapePlayer),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioPlaybackControl(audio: _audio(), compact: true),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Play'));
    await _settle(tester);
    await sessionController.pause();
    await preferences.save(
      'audio-1',
      const MemorySoundscapeSettings(
        soundscape: MemorySoundscape.stillness,
        volume: .1,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await sessionController.resume();

    expect(driver.events, ['play', 'pause', 'resume']);
    expect(soundscapePlayer.events, [
      'start:flowingWater',
      'stop',
      'start:stillness',
    ]);
    await sessionController.close();
    expect(soundscapePlayer.events.last, 'stop');
  });

  testWidgets('full playback offers a gentle optional soundscape', (
    tester,
  ) async {
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _ControlAssetStore(),
      driver: _ControlDriver(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          memorySoundscapePreferencesProvider.overrideWith(
            (ref) => MemorySoundscapePreferences(
              read: (_) async => null,
              write: (_, _) async {},
            ),
          ),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) => MemorySoundscapePlaybackCoordinator(
              player: _SilentSoundscapePlayer(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: AudioPlaybackControl(audio: _audio())),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Background sound'), findsOneWidget);
    expect(find.text('Quiet'), findsOneWidget);
    expect(find.text('Stillness'), findsOneWidget);
    expect(find.text('Flowing water'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

MemoryAudio _audio() => MemoryAudio(
  id: 'audio-1',
  encounterId: 'memory-1',
  revisionId: 'revision-1',
  storageKey: 'audio/memory.m4a',
  mimeType: 'audio/mp4',
  duration: const Duration(seconds: 7),
  byteSize: 3,
  waveform: const [0.2, 0.7],
  createdAt: DateTime.utc(2026, 8, 13),
);

class _ControlDriver implements MemoryAudioPlayerDriver {
  final events = <String>[];
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _statuses = StreamController<MemoryAudioDriverStatus>.broadcast();

  void emitPosition(Duration value) => _positions.add(value);
  void emitStatus(MemoryAudioDriverStatus value) => _statuses.add(value);

  @override
  Stream<Duration> get durationChanges => _durations.stream;

  @override
  Stream<Duration> get positionChanges => _positions.stream;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => _statuses.stream;

  @override
  Future<void> dispose() async {
    await _positions.close();
    await _durations.close();
    await _statuses.close();
  }

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {}

  @override
  Future<void> release(String assetId) async {}

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async =>
      events.add('play');

  @override
  Future<void> resume() async => events.add('resume');

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}
}

class _SilentSoundscapePlayer implements MemorySoundscapePlayer {
  final events = <String>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> start(
    MemorySoundscape soundscape, {
    required double volume,
  }) async => events.add('start:${soundscape.name}');

  @override
  Future<void> stop() async => events.add('stop');
}

class _ControlAssetStore implements AudioAssetStore {
  @override
  Future<AudioPlaybackSource?> open(String storageKey) async =>
      const FileAudioPlaybackSource('/private/memory.m4a');

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
  Future<void> delete(String storageKey) async {}

  @override
  Future<void> discardTemporary(String locator) => throw UnimplementedError();
}

class _ControlRepository implements MemoryAudioRepository {
  _ControlRepository(this.events);
  final List<String> events;

  @override
  Future<String?> deleteMetadata(String encounterId) async {
    events.add('metadata:$encounterId');
    return 'audio/memory.m4a';
  }

  @override
  Future<MemoryAudio> attach(
    MemoryAudioDraft draft, {
    required String encounterId,
    required String revisionId,
    required String durableKey,
    required int byteSize,
  }) => throw UnimplementedError();

  @override
  Future<Set<String>> ownedStorageKeys() => throw UnimplementedError();

  @override
  Stream<MemoryAudio?> watchForEncounter(String encounterId) =>
      const Stream.empty();
}

class _DeletionControlStore extends _ControlAssetStore {
  _DeletionControlStore(this.events);
  final List<String> events;

  @override
  Future<void> delete(String storageKey) async =>
      events.add('bytes:$storageKey');
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
