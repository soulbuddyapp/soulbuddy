import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/prayers/application/meditation_sound_bed_player.dart';
import 'package:soulbuddy/features/prayers/domain/meditation_session.dart';

void main() {
  test(
    'leaving during sound preparation cannot start playback later',
    () async {
      final audio = _Audio();
      final player = AudioplayersMeditationSoundBedPlayer(player: audio);
      final starting = player.start(
        MeditationSoundBed.hopefulPiano,
        volume: .18,
      );
      await audio.preparing.future;
      await player.stop();
      audio.ready.complete();
      await starting;
      expect(audio.playing, false);
      expect(audio.playCalls, 0);
    },
  );
}

class _Audio implements AudioPlayer {
  final preparing = Completer<void>();
  final ready = Completer<void>();
  bool playing = false;
  int playCalls = 0;

  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    if (!preparing.isCompleted) preparing.complete();
    await ready.future;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playCalls++;
    playing = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
