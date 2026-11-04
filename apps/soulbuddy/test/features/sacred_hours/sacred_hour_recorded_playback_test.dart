import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';
import 'package:soulbuddy/core/playback/spiritual_session_mini_player.dart';
import 'package:soulbuddy/core/playback/spiritual_session_providers.dart';
import 'package:soulbuddy/core/playback/system_playback_handler.dart';
import 'package:soulbuddy/features/record/audio/application/memory_audio_player.dart';
import 'package:soulbuddy/features/record/audio/data/audio_asset_store.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_recorded_playback.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_system_notification.dart';
import 'package:soulbuddy/features/sacred_hours/application/sacred_hour_continuity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reopening an occurrence retains its timer and selected recording', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const key = (route: '/sacred-hours/hour?occurrence=one', prayerMinutes: 5);
    final first = container.read(sacredHourContinuityProvider(key));
    first.controller.beginPrayer();
    first.controller.pause();
    first.track = const PrivateAudioTrack(
      id: 'track',
      storageKey: 'file',
      duration: Duration(minutes: 1),
    );
    final reopened = container.read(sacredHourContinuityProvider(key));
    expect(reopened.controller.state.isPaused, isTrue);
    expect(reopened.track?.id, 'track');
    expect(
      container
          .read(
            sacredHourContinuityProvider((
              route: '/sacred-hours/hour?occurrence=two',
              prayerMinutes: 5,
            )),
          )
          .track,
      isNull,
    );
  });
  test(
    'stopping the Android notification is safe without its plugin',
    () async {
      await SacredHourSystemNotification.stop();
    },
  );
  testWidgets('audio-only player offers close without a completion action', (
    tester,
  ) async {
    final driver = _Driver();
    final player = MemoryAudioPlaybackCoordinator(
      assetStore: _Store(),
      driver: driver,
    );
    final spiritual = SpiritualSessionController();
    await startSacredHourRecordedPlayback(
      spiritual: spiritual,
      player: player,
      track: const PrivateAudioTrack(
        id: 'track',
        storageKey: 'file',
        duration: Duration(minutes: 1),
      ),
      route: '/sacred-hours/hour',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spiritualSessionControllerProvider.overrideWithValue(spiritual),
        ],
        child: MaterialApp(
          home: Scaffold(body: SpiritualSessionMiniPlayer(onOpen: (_) {})),
        ),
      ),
    );
    expect(find.byKey(const Key('spiritual-session-complete')), findsNothing);
    expect(find.byTooltip('Close player'), findsOneWidget);
    await tester.tap(find.byTooltip('Close player'));
    await tester.pump();
    expect(driver.events.last, 'stop');
    await tester.runAsync(player.close);
    spiritual.dispose();
  });
  test('system playback controls respect active capture', () async {
    final driver = _Driver();
    final player = MemoryAudioPlaybackCoordinator(
      assetStore: _Store(),
      driver: driver,
    );
    final spiritual = SpiritualSessionController();
    final handler = SystemPlaybackHandler(spiritual);
    addTearDown(() async {
      handler.dispose();
      spiritual.dispose();
      await player.close();
    });
    await startSacredHourRecordedPlayback(
      spiritual: spiritual,
      player: player,
      track: const PrivateAudioTrack(
        id: 'track',
        storageKey: 'file',
        duration: Duration(minutes: 1),
      ),
      route: '/sacred-hours/hour',
    );
    expect(driver.events, ['play']);
    expect(handler.mediaItem.value?.id, 'voice-recording');
    await handler.pause();
    expect(driver.events.last, 'pause');
    final capture = Object();
    await spiritual.acquireCapture(capture);
    await handler.play();
    expect(driver.events.last, 'pause');
    spiritual.releaseCapture(capture);
    await handler.play();
    expect(driver.events.last, 'resume');
    await handler.stop();
    expect(driver.events.last, 'stop');
    expect(spiritual.state.session, isNull);
  });
  test('pausing or closing voice also quiets its sound bed', () async {
    final driver = _Driver();
    final player = MemoryAudioPlaybackCoordinator(
      assetStore: _Store(),
      driver: driver,
    );
    final spiritual = SpiritualSessionController();
    final handler = SystemPlaybackHandler(spiritual);
    var quieted = 0;
    final guard = SacredHourSoundBedGuard(player, 'track', () async {
      quieted++;
    });
    addTearDown(() async {
      guard.dispose();
      handler.dispose();
      spiritual.dispose();
      await player.close();
    });
    await startSacredHourRecordedPlayback(
      spiritual: spiritual,
      player: player,
      track: const PrivateAudioTrack(
        id: 'track',
        storageKey: 'file',
        duration: Duration(minutes: 1),
      ),
      route: '/hour',
    );
    await handler.pause();
    expect(quieted, 1);
    await handler.play();
    await handler.stop();
    expect(quieted, 2);
  });
  for (final systemAvailable in [false, true]) {
    testWidgets(
      'background playback respects system controls: $systemAvailable',
      (tester) async {
        final player = MemoryAudioPlaybackCoordinator(
          assetStore: _Store(),
          driver: _Driver(),
        );
        final spiritual = SpiritualSessionController();
        await startSacredHourRecordedPlayback(
          spiritual: spiritual,
          player: player,
          track: const PrivateAudioTrack(
            id: 'track',
            storageKey: 'file',
            duration: Duration(minutes: 1),
          ),
          route: '/sacred-hours/hour',
          systemPlaybackAvailable: systemAvailable,
        );
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
        );
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        );
        await tester.pumpAndSettle();
        expect(player.state.status, MemoryAudioPlaybackStatus.playing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        await tester.pump();
        expect(
          player.state.status,
          systemAvailable
              ? MemoryAudioPlaybackStatus.playing
              : MemoryAudioPlaybackStatus.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final closing = spiritual.close();
        await tester.pump();
        await closing;
        await tester.runAsync(player.close);
        spiritual.dispose();
      },
    );
  }
}

class _Store extends Fake implements AudioAssetStore {
  @override
  Future<AudioPlaybackSource?> open(String storageKey) async =>
      const FileAudioPlaybackSource('file');
}

class _Driver extends Fake implements MemoryAudioPlayerDriver {
  final events = <String>[];
  @override
  Stream<Duration> get positionChanges => const Stream.empty();
  @override
  Stream<Duration> get durationChanges => const Stream.empty();
  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => const Stream.empty();
  @override
  Future<void> play(String id, AudioPlaybackSource source) async {
    events.add('play');
  }

  @override
  Future<void> pause() async {
    events.add('pause');
  }

  @override
  Future<void> resume() async {
    events.add('resume');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {}
}
