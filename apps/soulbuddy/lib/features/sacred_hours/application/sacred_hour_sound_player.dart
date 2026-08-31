import 'package:audioplayers/audioplayers.dart';

import '../domain/sacred_hour.dart';

abstract interface class SacredHourSoundPlayer {
  Future<void> play(SacredHourSound sound);
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersSacredHourSoundPlayer implements SacredHourSoundPlayer {
  AudioplayersSacredHourSoundPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(SacredHourSound sound) async {
    final path = _assetPath(sound);
    if (path == null) return;
    await _player.stop();
    await _player.setVolume(.62);
    await _player.play(AssetSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

String? _assetPath(SacredHourSound sound) => switch (sound) {
  SacredHourSound.gentleChime => 'audio/sacred_hours/sacred_gentle_chime.wav',
  SacredHourSound.dawnChime => 'audio/sacred_hours/sacred_dawn_chime.wav',
  SacredHourSound.stillBell => 'audio/sacred_hours/sacred_still_bell.wav',
  SacredHourSound.eveningChime => 'audio/sacred_hours/sacred_evening_chime.wav',
  SacredHourSound.device || SacredHourSound.silent => null,
};
