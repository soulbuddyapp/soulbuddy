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
  int _generation = 0;
  bool _closed = false;
  Future<void> _pending = Future.value();
  Future<void>? _closing;

  Future<void> start(String assetId, MemorySoundscapeSettings settings) {
    if (_closed) return Future.value();
    _assetId = assetId;
    final generation = ++_generation;
    bool current() => !_closed && generation == _generation;
    return _enqueue(() async {
      if (!current()) return;
      await _player.start(
        settings.soundscape,
        volume: settings.validated.volume,
      );
      if (!current()) await _player.stop();
    });
  }

  Future<void> setVolume(String assetId, double volume) {
    if (_closed || _assetId != assetId) return Future.value();
    final generation = _generation;
    return _enqueue(() async {
      if (!_closed && _assetId == assetId && generation == _generation) {
        await _player.setVolume(_safeVolume(volume));
      }
    });
  }

  Future<void> stop(String assetId) {
    if (_closed || _assetId != assetId) return Future.value();
    _assetId = null;
    ++_generation;
    return _enqueue(_player.stop);
  }

  /// Stops whichever background belongs to the current audio session. Await
  /// this before opening the microphone, including when a start is in flight.
  Future<void> stopAll() {
    if (_closed) return _closing ?? Future.value();
    _assetId = null;
    ++_generation;
    return _enqueue(_player.stop);
  }

  Future<void> close() {
    if (_closed) return _closing ?? Future.value();
    _closed = true;
    _assetId = null;
    ++_generation;
    return _closing = _enqueue(_player.dispose);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final pending = _pending.then((_) => operation());
    _pending = pending.catchError((Object _) {});
    return pending;
  }
}

class AudioplayersMemorySoundscapePlayer implements MemorySoundscapePlayer {
  AudioplayersMemorySoundscapePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _pending = Future.value();
  Future<void>? _disposing;

  @override
  Future<void> start(MemorySoundscape soundscape, {required double volume}) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    return _enqueue(() async {
      if (!current()) return;
      await _player.stop();
      if (!current()) return;
      final assetPath = soundscape.assetPath;
      if (assetPath == null) return;
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
      await _player.play(AssetSource(assetPath));
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
