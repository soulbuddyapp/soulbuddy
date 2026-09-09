import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class OrientationPlayer {
  /// Actual media position. Implementations must discard queries from before a
  /// completed seek; the next valid sample can be delayed or natively clamped.
  Stream<Duration> get positions;
  Stream<bool> get playing;
  Stream<void> get completions;
  Future<void> prepare(String audioAsset);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> close();
}

class AudioplayersOrientationPlayer implements OrientationPlayer {
  AudioplayersOrientationPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    // Poll the media clock, never extrapolate it from elapsed wall time.
    _updater = _MediaPositionUpdater(getPosition: _player.getCurrentPosition);
    _player.positionUpdater = _updater;
  }

  final AudioPlayer _player;
  late final _MediaPositionUpdater _updater;
  Future<void>? _closing;

  @override
  Stream<Duration> get positions => _player.onPositionChanged;
  @override
  Stream<bool> get playing => _player.onPlayerStateChanged
      .map((state) => state == PlayerState.playing)
      .distinct();
  @override
  Stream<void> get completions => _player.onPlayerComplete;

  @override
  Future<void> prepare(String audioAsset) async {
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(
      AssetSource(
        audioAsset.startsWith('assets/') ? audioAsset.substring(7) : audioAsset,
      ),
    );
  }

  @override
  Future<void> play() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) async {
    _updater.beginSeek();
    try {
      await _player.seek(position);
    } finally {
      _updater.endSeek();
    }
  }

  // Native media-player rate and browser playbackRate retain the platform's
  // pitch correction. Low-latency playback changes pitch and is not used here.
  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);
  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      await _player.stop();
    } finally {
      await _player.dispose();
    }
  }
}

/// The package's default updater can publish an in-flight query after seek or
/// dispose. Tag each real media query so those results never reach the reader.
class _MediaPositionUpdater implements PositionUpdater {
  _MediaPositionUpdater({required this.getPosition});

  @override
  final Future<Duration?> Function() getPosition;
  final _positions = StreamController<Duration>.broadcast();
  Timer? _timer;
  int _generation = 0;
  bool _reading = false;
  bool _seeking = false;
  bool _disposed = false;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  void beginSeek() {
    _generation++;
    _seeking = true;
  }

  void endSeek() {
    _generation++;
    _seeking = false;
  }

  @override
  Future<void> update() async {
    if (_disposed || _reading || _seeking) return;
    final generation = _generation;
    _reading = true;
    try {
      final value = await getPosition();
      if (!_disposed && generation == _generation && value != null) {
        _positions.add(value);
      }
    } catch (error, stack) {
      if (!_disposed && generation == _generation) {
        _positions.addError(error, stack);
      }
    } finally {
      _reading = false;
    }
  }

  @override
  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      unawaited(update());
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  @override
  Future<void> stopAndUpdate() async {
    stop();
    await update();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stop();
    await _positions.close();
  }
}
