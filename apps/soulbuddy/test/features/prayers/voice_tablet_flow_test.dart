import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/prayers/presentation/voice_tablet_player.dart';
import 'package:soulbuddy/features/prayers/presentation/voice_tablet_sheet.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/providers/memory_audio_providers.dart';

void main() {
  test('a Voice Tablet track completes the shared playback command', () async {
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _FakeAudioStore(),
      driver: _FakeAudioDriver(),
    );
    addTearDown(coordinator.close);

    await coordinator
        .playTrack(
          const PrivateAudioTrack(
            id: 'audio-1',
            storageKey: 'voice/audio-1.m4a',
            duration: Duration(seconds: 30),
          ),
        )
        .timeout(const Duration(seconds: 1));

    expect(coordinator.state.status, MemoryAudioPlaybackStatus.playing);
  });

  testWidgets('offers one optional Prayer Refrain after the full recording', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: VoiceTabletSheet(
              source: VoiceTabletSourceTest.personal,
              title: 'Morning surrender',
              prayerBody: 'Father, keep me in your truth today.',
              initialFullDraft: VoiceTabletSourceTest.draft,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Your prayer is recorded'), findsOneWidget);
    expect(find.text('Add a short refrain'), findsOneWidget);
    expect(find.text('Save without a refrain'), findsOneWidget);
    expect(find.textContaining('Prayer Refrain'), findsOneWidget);
  });

  testWidgets('listening never records prayer without I prayed', (
    tester,
  ) async {
    final driver = _FakeAudioDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _FakeAudioStore(),
      driver: driver,
    );
    var played = 0;
    var prayed = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceTabletPlayer(
                tablet: _tablet(),
                onPlayed: (_) => played++,
                onPrayed: () => prayed++,
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(played, 1);
    expect(prayed, 0);

    await tester.tap(find.text('I prayed'));
    await tester.pump();
    expect(prayed, 1);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

abstract final class VoiceTabletSourceTest {
  static final personal = VoiceTabletSource.personal(
    prayerId: 'prayer-1',
    revisionId: 'revision-1',
  );
  static final draft = RecordedAudioDraft(
    temporaryKey: 'temporary/full.m4a',
    mimeType: 'audio/mp4',
    duration: const Duration(seconds: 30),
    waveform: const [0.1, 0.4],
  );
}

VoiceTablet _tablet() => VoiceTablet(
  id: 'tablet-1',
  ownerId: 'owner-1',
  source: VoiceTabletSource.personal(
    prayerId: 'prayer-1',
    revisionId: 'revision-1',
  ),
  title: 'Morning surrender',
  fullAudio: VoiceTabletAudio(
    id: 'audio-1',
    kind: VoiceTabletAudioKind.fullPrayer,
    storageKey: 'voice/audio-1.m4a',
    mimeType: 'audio/mp4',
    duration: const Duration(seconds: 30),
    byteSize: 1024,
    waveform: const [0.1, 0.4, 0.8, 0.2],
    createdAt: DateTime.utc(2026, 8, 26),
  ),
  createdAt: DateTime.utc(2026, 8, 26),
  updatedAt: DateTime.utc(2026, 8, 26),
);

class _FakeAudioStore implements AudioAssetStore {
  @override
  Future<AudioPlaybackSource?> open(String storageKey) async =>
      BytesAudioPlaybackSource(
        Uint8List.fromList([1, 2, 3]),
        mimeType: 'audio/mp4',
      );

  @override
  Future<TemporaryAudio> allocateTemporary({
    required String takeId,
    required String extension,
  }) => throw UnimplementedError();

  @override
  Future<void> cleanup(
    Set<String> referencedStorageKeys, {
    required DateTime olderThan,
  }) async {}

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String storageKey) async {}

  @override
  Future<void> discardTemporary(String locator) async {}
}

class _FakeAudioDriver implements MemoryAudioPlayerDriver {
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final statuses = StreamController<MemoryAudioDriverStatus>.broadcast();

  @override
  Stream<Duration> get durationChanges => durations.stream;

  @override
  Stream<Duration> get positionChanges => positions.stream;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => statuses.stream;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async {}

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {}

  @override
  Future<void> release(String assetId) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await positions.close();
    await durations.close();
    await statuses.close();
  }
}
