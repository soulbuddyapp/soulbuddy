import 'package:audioplayers/audioplayers.dart';

import '../domain/meditation_session.dart';

abstract interface class MeditationSoundBedPlayer {
  Future<void> start(MeditationSoundBed bed, {required double volume});
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersMeditationSoundBedPlayer implements MeditationSoundBedPlayer {
  AudioplayersMeditationSoundBedPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume.clamp(0.0, 0.35));
    await _player.play(AssetSource(bed.assetPath));
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 0.35));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
