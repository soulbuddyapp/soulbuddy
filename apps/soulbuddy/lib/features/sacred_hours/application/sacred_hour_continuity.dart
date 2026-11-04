import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../record/audio/application/memory_audio_player.dart';
import 'sacred_hour_session_controller.dart';

typedef SacredHourContinuityKey = ({String route, int prayerMinutes});

class SacredHourContinuity {
  SacredHourContinuity(int prayerMinutes)
    : controller = SacredHourSessionController(prayerMinutes: prayerMinutes);
  final SacredHourSessionController controller;
  PrivateAudioTrack? track;
}

final sacredHourContinuityProvider =
    Provider.family<SacredHourContinuity, SacredHourContinuityKey>((ref, key) {
      final session = SacredHourContinuity(key.prayerMinutes);
      ref.onDispose(session.controller.dispose);
      return session;
    });

class SacredHourSoundBedGuard {
  SacredHourSoundBedGuard(this.player, this.trackId, this.quiet) {
    _playing = _isPlaying;
    player.addListener(_changed);
  }
  final MemoryAudioPlaybackCoordinator player;
  final String trackId;
  final Future<void> Function() quiet;
  late bool _playing;

  bool get _isPlaying =>
      player.state.assetId == trackId &&
      player.state.status == MemoryAudioPlaybackStatus.playing;

  void _changed() {
    final playing = _isPlaying;
    if (_playing && !playing) unawaited(quiet().catchError((Object _) {}));
    _playing = playing;
  }

  void dispose() => player.removeListener(_changed);
}
