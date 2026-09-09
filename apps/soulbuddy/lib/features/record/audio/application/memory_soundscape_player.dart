import 'package:audioplayers/audioplayers.dart';

import '../domain/memory_soundscape.dart';

abstract interface class MemorySoundscapePlayer {
  Future<void> start(MemorySoundscape soundscape, {required double volume});
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

class MemorySoundscapePlaybackCoordinator {
  MemorySoundscapePlaybackCoordinator({required MemorySoundscapePlayer player})
    : _player = player;

  final MemorySoundscapePlayer _player;
  String? _assetId;

  Future<void> start(String assetId, MemorySoundscapeSettings settings) async {
    _assetId = assetId;
    await _player.start(settings.soundscape, volume: settings.validated.volume);
  }

  Future<void> setVolume(String assetId, double volume) async {
    if (_assetId == assetId) await _player.setVolume(volume);
  }

  Future<void> stop(String assetId) async {
    if (_assetId != assetId) return;
    _assetId = null;
    await _player.stop();
  }

  Future<void> close() async {
    _assetId = null;
    await _player.dispose();
  }
}

class AudioplayersMemorySoundscapePlayer implements MemorySoundscapePlayer {
  AudioplayersMemorySoundscapePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _started = false;

  @override
  Future<void> start(
    MemorySoundscape soundscape, {
    required double volume,
  }) async {
    if (_started) await stop();
    final assetPath = soundscape.assetPath;
    if (assetPath == null) return;
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
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
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume.clamp(0.0, 0.35));
    await _player.play(AssetSource(assetPath));
    _started = true;
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 0.35));

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
