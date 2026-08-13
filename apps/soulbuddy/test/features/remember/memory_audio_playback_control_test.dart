import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_deletion.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/memory_audio_repository.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
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
  Future<void> play(AudioPlaybackSource source) async => events.add('play');

  @override
  Future<void> resume() async => events.add('resume');

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}
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
