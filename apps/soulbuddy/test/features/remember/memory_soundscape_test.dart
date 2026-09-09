import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/features/record/audio/application/memory_soundscape_player.dart';
import 'package:soulbuddy/features/record/audio/data/memory_soundscape_preferences.dart';
import 'package:soulbuddy/features/record/audio/domain/memory_soundscape.dart';

void main() {
  test('defaults to quiet and validates the gentle volume range', () {
    expect(
      MemorySoundscapeSettings.defaults.soundscape,
      MemorySoundscape.quiet,
    );
    expect(MemorySoundscapeSettings.defaults.volume, 0.15);
    expect(
      const MemorySoundscapeSettings(
        soundscape: MemorySoundscape.stillness,
        volume: 4,
      ).validated.volume,
      0.35,
    );
  });

  test('persists a soundscape per clean audio asset', () async {
    final values = <String, String>{};
    final repository = MemorySoundscapePreferences(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
    );
    const settings = MemorySoundscapeSettings(
      soundscape: MemorySoundscape.flowingWater,
      volume: 0.2,
    );

    await repository.save('audio-1', settings);

    expect(await repository.load('audio-1'), settings);
    expect(await repository.load('audio-2'), MemorySoundscapeSettings.defaults);
  });

  test('sound bed mixes without taking foreground audio focus', () async {
    final audioPlayer = _FakeAudioPlayer();
    final player = AudioplayersMemorySoundscapePlayer(player: audioPlayer);

    await player.start(MemorySoundscape.stillness, volume: 0.8);

    expect(audioPlayer.modeSet, PlayerMode.mediaPlayer);
    expect(audioPlayer.contextSet?.android.audioFocus, AndroidAudioFocus.none);
    expect(audioPlayer.volumeSet, 0.35);
    expect(audioPlayer.releaseModeSet, ReleaseMode.loop);
    expect(
      audioPlayer.sourceSet,
      isA<AssetSource>().having(
        (source) => source.path,
        'path',
        'audio/meditation/stillness.mp3',
      ),
    );
  });
}

class _FakeAudioPlayer implements AudioPlayer {
  PlayerMode? modeSet;
  AudioContext? contextSet;
  double? volumeSet;
  ReleaseMode? releaseModeSet;
  Source? sourceSet;

  @override
  Future<void> setPlayerMode(PlayerMode mode) async => modeSet = mode;

  @override
  Future<void> setAudioContext(AudioContext context) async =>
      contextSet = context;

  @override
  Future<void> setVolume(double volume) async => volumeSet = volume;

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async => releaseModeSet = mode;

  @override
  Future<void> stop() async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async => sourceSet = source;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
