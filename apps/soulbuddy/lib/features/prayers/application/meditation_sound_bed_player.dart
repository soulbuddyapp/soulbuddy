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
  int _generation = 0;
  bool _disposed = false;
  Future<void> _pending = Future.value();

  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    final starting = _pending.then((_) async {
      if (!current()) return;
      await _player.stop();
      if (!current()) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      if (!current()) return;
      await _player.setVolume(volume.clamp(0.0, 0.35));
      if (!current()) return;
      await _player.play(AssetSource(bed.assetPath));
      if (!current()) await _player.stop();
    });
    _pending = starting.catchError((Object _) {});
    return starting;
  }

  @override
  Future<void> setVolume(double volume) =>
      _disposed ? Future.value() : _player.setVolume(volume.clamp(0.0, 0.35));

  @override
  Future<void> stop() {
    ++_generation;
    return _disposed ? Future.value() : _player.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    await _player.stop();
    await _pending;
    await _player.dispose();
  }
}
