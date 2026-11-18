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
  Future<void>? _disposing;

  @override
  Future<void> start(MeditationSoundBed bed, {required double volume}) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    return _enqueue(() async {
      if (!current()) return;
      await _player.stop();
      if (!current()) return;
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      if (!current()) return;
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      if (!current()) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      if (!current()) return;
      await _player.setVolume(_safeVolume(volume));
      if (!current()) return;
      await _player.play(AssetSource(bed.assetPath));
      if (!current()) await _player.stop();
    });
  }

  @override
  Future<void> setVolume(double volume) {
    if (_disposed) return Future.value();
    final generation = _generation;
    return _enqueue(() async {
      if (!_disposed && generation == _generation) {
        await _player.setVolume(_safeVolume(volume));
      }
    });
  }

  @override
  Future<void> stop() {
    if (_disposed) return _disposing ?? Future.value();
    ++_generation;
    return _enqueue(_player.stop);
  }

  @override
  Future<void> dispose() {
    if (_disposed) return _disposing ?? Future.value();
    _disposed = true;
    ++_generation;
    return _disposing = _enqueue(() async {
      await _player.stop();
      await _player.dispose();
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final pending = _pending.then((_) => operation());
    _pending = pending.catchError((Object _) {});
    return pending;
  }
}

double _safeVolume(double volume) =>
    volume.isFinite ? volume.clamp(0.0, 0.35) : 0.15;
