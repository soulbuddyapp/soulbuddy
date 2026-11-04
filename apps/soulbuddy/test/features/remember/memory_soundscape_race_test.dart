import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/memory_soundscape_player.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_soundscape.dart';

void main() {
  test('capture waits until a pending background start is silent', () async {
    final player = _DelayedSoundscape();
    final coordinator = MemorySoundscapePlaybackCoordinator(player: player);
    final starting = coordinator.start(
      'one',
      _settings(MemorySoundscape.stillness),
    );
    await player.starting.future;

    var stopped = false;
    final stopping = coordinator.stopAll().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, false);
    player.ready.complete();
    await starting;
    await stopping;

    expect(player.playing, false);
  });

  test('old-owner cleanup cannot stop the new background', () async {
    final player = _DelayedSoundscape();
    final coordinator = MemorySoundscapePlaybackCoordinator(player: player);
    final first = coordinator.start(
      'one',
      _settings(MemorySoundscape.stillness),
    );
    await player.starting.future;

    final second = coordinator.start(
      'two',
      _settings(MemorySoundscape.flowingWater),
    );
    await coordinator.stop('one');
    player.ready.complete();
    await first;
    await second;

    expect(player.playing, true);
    expect(player.soundscape, MemorySoundscape.flowingWater);
    await coordinator.close();
    expect(player.playing, false);
    await coordinator.start('three', _settings(MemorySoundscape.stillness));
    expect(player.soundscape, MemorySoundscape.flowingWater);
  });

  test('stopping during native preparation prevents a late play', () async {
    final audio = _DelayedAudio(delayPreparation: true);
    final player = AudioplayersMemorySoundscapePlayer(player: audio);
    final starting = player.start(MemorySoundscape.stillness, volume: .15);
    await audio.waiting.future;

    final stopping = player.stop();
    audio.ready.complete();
    await starting;
    await stopping;

    expect(audio.playCalls, 0);
    expect(audio.playing, false);
  });

  test('stop awaits the end of a late native start', () async {
    final audio = _DelayedAudio(delayPreparation: false);
    final player = AudioplayersMemorySoundscapePlayer(player: audio);
    final starting = player.start(MemorySoundscape.stillness, volume: .15);
    await audio.waiting.future;

    var stopped = false;
    final stopping = player.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, false);
    audio.ready.complete();
    await starting;
    await stopping;

    expect(audio.playCalls, 1);
    expect(audio.playing, false);
  });
}

MemorySoundscapeSettings _settings(MemorySoundscape soundscape) =>
    MemorySoundscapeSettings(soundscape: soundscape, volume: .15);

class _DelayedSoundscape implements MemorySoundscapePlayer {
  final starting = Completer<void>();
  final ready = Completer<void>();
  bool playing = false;
  MemorySoundscape? soundscape;

  @override
  Future<void> start(MemorySoundscape value, {required double volume}) async {
    if (!starting.isCompleted) starting.complete();
    await ready.future;
    soundscape = value;
    playing = true;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> dispose() async => playing = false;
}

class _DelayedAudio implements AudioPlayer {
  _DelayedAudio({required this.delayPreparation});

  final bool delayPreparation;
  final waiting = Completer<void>();
  final ready = Completer<void>();
  bool playing = false;
  int playCalls = 0;

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> setPlayerMode(PlayerMode mode) async {}

  @override
  Future<void> setAudioContext(AudioContext context) async {
    if (delayPreparation) {
      waiting.complete();
      await ready.future;
    }
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}

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
    if (!delayPreparation) {
      waiting.complete();
      await ready.future;
    }
    playing = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
