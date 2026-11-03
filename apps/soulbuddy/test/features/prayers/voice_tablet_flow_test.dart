import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/spiritual_session_providers.dart';
import 'package:soulbuddy/features/prayers/domain/voice_tablet.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_reference.dart';
import 'package:soulbuddy/features/prayers/domain/prayer_session.dart';
import 'package:soulbuddy/features/prayers/data/prayer_practice_repository.dart';
import 'package:soulbuddy/features/prayers/data/voice_tablet_repository.dart';
import 'package:soulbuddy/features/prayers/presentation/voice_tablet_player.dart';
import 'package:soulbuddy/features/prayers/presentation/voice_tablet_sheet.dart';
import 'package:soulbuddy/features/prayers/providers/voice_tablet_providers.dart';
import 'package:soulbuddy/features/prayers/providers/prayer_practice_providers.dart';
import 'package:soulbuddy/features/record/audio/application/audio_capture_controller.dart';
import 'package:soulbuddy/features/record/audio/application/audio_recorder.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/application/memory_soundscape_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/record/audio/data/memory_soundscape_preferences.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_audio.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_soundscape.dart';
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

  testWidgets('switching sessions closes old audio before starting tablet', (
    tester,
  ) async {
    final driver = _FakeAudioDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _FakeAudioStore(),
      driver: driver,
    );
    await coordinator.playTrack(
      const PrivateAudioTrack(
        id: 'old-audio',
        storageKey: 'voice/old.m4a',
        duration: Duration(seconds: 30),
      ),
    );
    driver.events.clear();
    final sessions = SpiritualSessionController();
    await sessions.begin(
      SpiritualSession(
        id: 'memory:old',
        kind: SpiritualSessionKind.memory,
        title: 'Old memory',
        route: '/remember/old',
        canPause: true,
        completionLabel: 'Close',
        onPause: coordinator.pause,
        onResume: () async {},
        onComplete: coordinator.stop,
        onClose: coordinator.stop,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(sessions),
          memorySoundscapePreferencesProvider.overrideWithValue(_preferences()),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) => MemorySoundscapePlaybackCoordinator(player: _Background()),
          ),
          prayerPracticeRepositoryProvider.overrideWith(
            (ref) async => _PracticeRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceTabletPlayer(tablet: _tablet()),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Listen'));
    await _settle(tester);

    expect(driver.events, ['stop', 'play']);
    expect(coordinator.state.status, MemoryAudioPlaybackStatus.playing);
    expect(sessions.state.session?.id, 'prayer:audio-1');
  });

  testWidgets('compact saved prayer recording has one prayer action', (
    tester,
  ) async {
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _FakeAudioStore(),
      driver: _FakeAudioDriver(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(
            SpiritualSessionController(),
          ),
          memorySoundscapePreferencesProvider.overrideWithValue(_preferences()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VoiceTabletPlayer(
              tablet: _tablet(),
              compact: true,
              showPrayerActions: false,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byTooltip('Listen'), findsOneWidget);
    expect(find.text('I prayed'), findsNothing);
    expect(find.text('Pray and remain'), findsNothing);
    expect(find.text('Voice Tablet'), findsNothing);
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

  testWidgets(
    'real capture handoff remains available until Voice Tablet save',
    (tester) async {
      final store = _CommittingAudioStore();
      final recorder = _CaptureRecorder(['temporary/full.m4a']);
      final repository = _VoiceTabletRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioAssetStoreProvider.overrideWith((ref) async => store),
            voiceTabletRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            voiceTabletAudioCaptureControllerProvider.overrideWith((ref, kind) {
              return AudioCaptureController(
                recorder: recorder,
                allocateTemporary: () async => const TemporaryAudio(
                  key: 'temporary/full.m4a',
                  locator: 'temporary/full.m4a',
                ),
                maximumDuration: kind == VoiceTabletAudioKind.refrain
                    ? maximumPrayerRefrainDuration
                    : maximumMemoryAudioDuration,
              );
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VoiceTabletSheet(
                source: VoiceTabletSourceTest.personal,
                title: 'Morning surrender',
                prayerBody: 'Father, keep me in your truth today.',
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Begin recording'));
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await _settle(tester);
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      expect(recorder.discarded, isEmpty);
      await tester.tap(find.text('Save without a refrain'));
      await _settle(tester);

      expect(store.committedTemporaryKeys, ['temporary/full.m4a']);
      expect(repository.created, hasLength(1));
      expect(recorder.discarded, isEmpty);
    },
  );

  testWidgets('record again after failed save replaces committed audio', (
    tester,
  ) async {
    final store = _CommittingAudioStore();
    final recorder = _CaptureRecorder([
      'temporary/first.m4a',
      'temporary/second.m4a',
    ]);
    final repository = _VoiceTabletRepository()..failuresRemaining = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioAssetStoreProvider.overrideWith((ref) async => store),
          voiceTabletRepositoryProvider.overrideWith((ref) async => repository),
          voiceTabletAudioCaptureControllerProvider.overrideWith((ref, kind) {
            return AudioCaptureController(
              recorder: recorder,
              allocateTemporary: () async => const TemporaryAudio(
                key: 'temporary/allocated.m4a',
                locator: 'temporary/allocated.m4a',
              ),
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VoiceTabletSheet(
              source: VoiceTabletSourceTest.personal,
              title: 'Morning surrender',
              prayerBody: 'Father, keep me in your truth today.',
            ),
          ),
        ),
      ),
    );

    for (var take = 0; take < 2; take++) {
      await _settle(tester);
      await tester.tap(find.text('Begin recording'));
      await tester.pump();
      await tester.tap(find.text('Stop'));
      await _settle(tester);
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      await tester.tap(find.text('Save without a refrain'));
      await _settle(tester);
      if (take == 0) await tester.tap(find.text('Record again'));
    }

    expect(store.committedTemporaryKeys, [
      'temporary/first.m4a',
      'temporary/second.m4a',
    ]);
    expect(store.deletedStorageKeys, hasLength(1));
    expect(repository.created, hasLength(1));
  });

  testWidgets('system Back cleans a failed Voice Tablet draft', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _CommittingAudioStore();
    final recorder = _CaptureRecorder(['temporary/full.m4a']);
    final repository = _VoiceTabletRepository()..failuresRemaining = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioAssetStoreProvider.overrideWith((ref) async => store),
          voiceTabletRepositoryProvider.overrideWith((ref) async => repository),
          voiceTabletAudioCaptureControllerProvider.overrideWith((ref, kind) {
            return AudioCaptureController(
              recorder: recorder,
              allocateTemporary: () async => const TemporaryAudio(
                key: 'temporary/full.m4a',
                locator: 'temporary/full.m4a',
              ),
            );
          }),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showVoiceTabletSheet(
                  context,
                  source: VoiceTabletSourceTest.personal,
                  title: 'Morning surrender',
                  prayerBody: 'Father, keep me in your truth today.',
                ),
                child: const Text('Open Voice Tablet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Voice Tablet'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Begin recording'));
    await tester.tap(find.text('Begin recording'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Save without a refrain'));
    await _settle(tester);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(find.text('Voice Tablet'), findsNothing);
    expect(store.deletedStorageKeys, hasLength(1));
    expect(store.discardedTemporaryKeys, ['temporary/full.m4a']);
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
          memorySoundscapePreferencesProvider.overrideWithValue(_preferences()),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) => MemorySoundscapePlaybackCoordinator(player: _Background()),
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

  testWidgets('prayer mix and completion survive leaving the player', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final driver = _FakeAudioDriver();
    final coordinator = MemoryAudioPlaybackCoordinator(
      assetStore: _FakeAudioStore(),
      driver: driver,
    );
    addTearDown(coordinator.close);
    final sessions = SpiritualSessionController();
    final background = _Background();
    final practice = _PracticeRepository();
    final preferences = _preferences();
    await preferences.save(
      'audio-1',
      const MemorySoundscapeSettings(
        soundscape: MemorySoundscape.flowingWater,
        volume: .15,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryAudioPlaybackCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          spiritualSessionControllerProvider.overrideWithValue(sessions),
          memorySoundscapePreferencesProvider.overrideWithValue(preferences),
          memorySoundscapePlaybackProvider.overrideWith(
            (ref) => MemorySoundscapePlaybackCoordinator(player: background),
          ),
          prayerPracticeRepositoryProvider.overrideWith(
            (ref) async => practice,
          ),
          prayerDeviceTimezoneProvider.overrideWithValue(
            () async => 'Africa/Lagos',
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) => show
                  ? SingleChildScrollView(
                      child: VoiceTabletPlayer(tablet: _tablet()),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen'));
    await _settle(tester);
    expect(background.playing, true);
    expect(practice.recorded, isEmpty);
    visible.value = false;
    await tester.pump();

    driver.positions.add(const Duration(seconds: 8));
    await tester.pump();
    expect(sessions.state.position, const Duration(seconds: 8));
    driver.statuses.add(MemoryAudioDriverStatus.paused);
    await tester.pump();
    expect(background.playing, false);
    expect(sessions.state.status, SpiritualSessionStatus.paused);
    await sessions.resume();
    expect(background.playing, true);
    driver.statuses.add(MemoryAudioDriverStatus.completed);
    await tester.pump();
    expect(background.playing, false);
    expect(sessions.state.session, isNull);

    visible.value = true;
    await _settle(tester);
    await tester.tap(find.text('Listen'));
    await _settle(tester);
    visible.value = false;
    await tester.pump();
    await sessions.complete();

    expect(background.playing, false);
    expect(practice.recorded.single.id, 'prayer-1');
    expect(practice.timezone, 'Africa/Lagos');
    expect(tester.takeException(), isNull);
  });
}

MemorySoundscapePreferences _preferences() {
  final values = <String, String>{};
  return MemorySoundscapePreferences(
    read: (key) async => values[key],
    write: (key, value) async => values[key] = value,
  );
}

class _Background implements MemorySoundscapePlayer {
  bool playing = false;

  @override
  Future<void> start(
    MemorySoundscape soundscape, {
    required double volume,
  }) async {
    playing = soundscape != MemorySoundscape.quiet;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> dispose() async => playing = false;
}

class _PracticeRepository implements PrayerPracticeRepository {
  final recorded = <PrayerReference>[];
  String? timezone;

  @override
  Future<PrayerSession> recordSession({
    required PrayerReference prayer,
    required String timezone,
    String? revisionId,
    String? reminderId,
    String? occurrenceKey,
    String? idempotencyKey,
  }) async {
    recorded.add(prayer);
    this.timezone = timezone;
    return PrayerSession(
      id: 'session-${recorded.length}',
      ownerId: 'owner-1',
      prayer: prayer,
      prayerRevisionId: revisionId,
      source: PrayerSessionSource.manual,
      occurredAt: DateTime.utc(2026, 11, 3),
      localDate: DateTime(2026, 11, 3),
      timezone: timezone,
      deviceId: 'device-1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  final events = <String>[];
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
  Future<void> play(String assetId, AudioPlaybackSource source) async =>
      events.add('play');

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {}

  @override
  Future<void> release(String assetId) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<void> dispose() async {
    await positions.close();
    await durations.close();
    await statuses.close();
  }
}

class _CaptureRecorder implements AudioRecorderGateway {
  _CaptureRecorder(this.results);

  final List<String> results;
  final amplitudesController = StreamController<double>.broadcast();
  final discarded = <String>[];

  @override
  Stream<double> get amplitudes => amplitudesController.stream;

  @override
  bool get canPause => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> discard(AudioRecorderResult result) async {
    discarded.add(result.locator);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(TemporaryAudio temporary) async {}

  @override
  Future<AudioRecorderResult> stop() async =>
      AudioRecorderResult(locator: results.removeAt(0), mimeType: 'audio/mp4');
}

class _CommittingAudioStore extends _FakeAudioStore {
  final committedTemporaryKeys = <String>[];
  final deletedStorageKeys = <String>[];
  final discardedTemporaryKeys = <String>[];

  @override
  Future<void> discardTemporary(String locator) async {
    discardedTemporaryKeys.add(locator);
  }

  @override
  Future<CommittedAudio> commitTemporary(
    TemporaryAudio temporary, {
    required String assetId,
    required String mimeType,
  }) async {
    committedTemporaryKeys.add(temporary.key);
    return CommittedAudio(storageKey: 'voice/$assetId.m4a', byteSize: 64);
  }

  @override
  Future<void> delete(String storageKey) async {
    deletedStorageKeys.add(storageKey);
  }
}

class _VoiceTabletRepository implements VoiceTabletRepository {
  final created = <VoiceTabletCreateRequest>[];
  var failuresRemaining = 0;

  @override
  Future<VoiceTablet> create(VoiceTabletCreateRequest request) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('metadata unavailable');
    }
    created.add(request);
    final attachment = request.fullRecording;
    return VoiceTablet(
      id: 'tablet-created',
      ownerId: 'owner-1',
      source: request.source,
      title: request.title,
      fullAudio: VoiceTabletAudio(
        id: attachment.id,
        kind: attachment.kind,
        storageKey: attachment.committed.storageKey,
        mimeType: attachment.draft.mimeType,
        duration: attachment.draft.duration,
        byteSize: attachment.committed.byteSize,
        waveform: attachment.draft.waveform,
        createdAt: DateTime.utc(2026, 8, 26),
      ),
      createdAt: DateTime.utc(2026, 8, 26),
      updatedAt: DateTime.utc(2026, 8, 26),
    );
  }

  @override
  Future<Set<String>> archive(String tabletId) async => {};

  @override
  Future<Set<String>> ownedStorageKeys() async => {};

  @override
  Future<VoiceTabletReplacement> replaceAudio(
    String tabletId,
    VoiceTabletAudioAttachment replacement,
  ) => throw UnimplementedError();

  @override
  Stream<VoiceTablet?> watch(String id) => const Stream.empty();

  @override
  Stream<VoiceTablet?> watchForSource(VoiceTabletSource source) =>
      const Stream.empty();
}
