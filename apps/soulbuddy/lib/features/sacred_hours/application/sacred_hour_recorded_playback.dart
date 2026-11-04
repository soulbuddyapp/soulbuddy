import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/playback/spiritual_session.dart';
import '../../../core/playback/spiritual_session_controller.dart';
import '../../record/audio/application/memory_audio_player.dart';

Future<void> startSacredHourRecordedPlayback({
  required SpiritualSessionController spiritual,
  required MemoryAudioPlaybackCoordinator player,
  required PrivateAudioTrack track,
  required String route,
  bool systemPlaybackAvailable = false,
}) async {
  final sessionId = 'sacred-hour:$route:${track.id}';
  final lifecycle = _PlaybackLifecycle(
    spiritual,
    sessionId,
    systemPlaybackAvailable,
  );
  var starting = true;
  late void Function() listener;
  listener = () {
    if (spiritual.state.session?.id != sessionId) {
      player.removeListener(listener);
      lifecycle.close();
      return;
    }
    final state = player.state;
    if (state.assetId != track.id) {
      if (!starting) {
        player.removeListener(listener);
        lifecycle.close();
        spiritual.finishPlayback(sessionId);
      }
      return;
    }
    spiritual.updateProgress(
      sessionId: sessionId,
      position: state.position,
      duration: state.duration,
      status: switch (state.status) {
        MemoryAudioPlaybackStatus.playing => SpiritualSessionStatus.playing,
        MemoryAudioPlaybackStatus.paused => SpiritualSessionStatus.paused,
        _ => null,
      },
    );
    if (!starting &&
        (state.status == MemoryAudioPlaybackStatus.completed ||
            state.status == MemoryAudioPlaybackStatus.idle ||
            state.status == MemoryAudioPlaybackStatus.error)) {
      player.removeListener(listener);
      lifecycle.close();
      spiritual.finishPlayback(sessionId);
    }
  };

  Future<void> start() async {
    starting = true;
    try {
      await player.playTrack(track);
    } finally {
      starting = false;
      listener();
    }
  }

  Future<void> stop() async {
    player.removeListener(listener);
    lifecycle.close();
    if (player.state.assetId == track.id) await player.stop();
  }

  await spiritual.begin(
    SpiritualSession(
      id: sessionId,
      kind: SpiritualSessionKind.prayer,
      title: 'Voice recording',
      route: route,
      canPause: true,
      supportsSystemPlayback: true,
      showCompletion: false,
      onStart: () async {
        lifecycle.start();
        player.addListener(listener);
        await start();
      },
      onPause: () async {
        if (player.state.assetId == track.id) await player.pause();
      },
      onResume: start,
      onSeek: player.seek,
      onComplete: stop,
      onClose: stop,
    ),
  );
}

class _PlaybackLifecycle with WidgetsBindingObserver {
  _PlaybackLifecycle(this.spiritual, this.sessionId, this.systemAvailable);
  final SpiritualSessionController spiritual;
  final String sessionId;
  final bool systemAvailable;
  bool _observing = false;

  void start() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void close() {
    if (!_observing) return;
    _observing = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !systemAvailable &&
        spiritual.state.session?.id == sessionId) {
      unawaited(spiritual.pause().catchError((Object _) {}));
    }
  }
}
