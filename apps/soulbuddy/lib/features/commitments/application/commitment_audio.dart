import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CommitmentAudioAsset {
  const CommitmentAudioAsset({
    required this.id,
    required this.path,
    required this.transcript,
    required this.captions,
    required this.duration,
  });
  final String id;
  final String path;
  final String transcript;
  final List<Map<String, dynamic>> captions;
  final Duration duration;

  static Future<CommitmentAudioAsset> load(String id) async {
    final json =
        jsonDecode(
              await rootBundle.loadString(
                'assets/audio/commitments/catalog_v1.json',
              ),
            )
            as Map<String, dynamic>;
    final item = (json['assets'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((entry) => entry['id'] == id);
    return CommitmentAudioAsset(
      id: id,
      path: item['path'] as String,
      transcript: item['transcript'] as String? ?? '',
      captions: (item['captions'] as List? ?? []).cast<Map<String, dynamic>>(),
      duration: Duration(milliseconds: (item['durationMs'] as num).round()),
    );
  }
}

/// Serial commands plus an epoch prevent a delayed load from starting after
/// navigation, interruption, or disposal. Source positions drive captions.
class CommitmentAudio extends ChangeNotifier {
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _commands = Future.value();
  int _epoch = 0;
  bool _disposed = false;
  bool _sourceReady = false;
  Future<void> Function()? _restart;
  bool playing = false;
  bool unavailable = false;
  bool complete = false;
  double speed = .85;
  Duration position = Duration.zero;
  CommitmentAudioAsset? asset;

  CommitmentAudio({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subscriptions.add(
      _player.onPositionChanged.listen((value) {
        position = value;
        _notify();
      }),
    );
    _subscriptions.add(
      _player.onPlayerComplete.listen((_) {
        playing = false;
        complete = true;
        _notify();
      }),
    );
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    return _commands = _commands.then((_) async {
      try {
        await action();
      } catch (_) {
        unavailable = true;
        playing = false;
        _notify();
      }
    });
  }

  Future<void> play(String id, {double volume = 1, bool loop = false}) {
    _restart = () => play(id, volume: volume, loop: loop);
    _sourceReady = false;
    final epoch = ++_epoch;
    complete = false;
    unavailable = false;
    return _enqueue(() async {
      await _player.stop();
      final loaded = await CommitmentAudioAsset.load(id);
      if (_disposed || epoch != _epoch) return;
      asset = loaded;
      position = Duration.zero;
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.setVolume(volume);
      await _player.setPlaybackRate(speed);
      if (_disposed || epoch != _epoch) return;
      await _player.play(AssetSource(loaded.path.replaceFirst('assets/', '')));
      if (_disposed || epoch != _epoch) {
        await _player.stop();
        return;
      }
      _sourceReady = true;
      playing = true;
      _notify();
    });
  }

  Future<void> pause() {
    ++_epoch;
    playing = false;
    _notify();
    return _enqueue(() async {
      await _player.pause();
    });
  }

  Future<void> playPath(String path, {double volume = 1, bool loop = false}) {
    _restart = () => playPath(path, volume: volume, loop: loop);
    _sourceReady = false;
    final epoch = ++_epoch;
    complete = false;
    unavailable = false;
    return _enqueue(() async {
      await _player.stop();
      if (_disposed || epoch != _epoch) return;
      asset = null;
      position = Duration.zero;
      await _player.setPlaybackRate(1);
      await _player.setVolume(volume);
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      if (_disposed || epoch != _epoch) return;
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
      if (_disposed || epoch != _epoch) {
        await _player.stop();
        return;
      }
      _sourceReady = true;
      playing = true;
      _notify();
    });
  }

  Future<void> playBytes(Uint8List bytes, {String mimeType = 'audio/mpeg'}) {
    _restart = () => playBytes(bytes, mimeType: mimeType);
    _sourceReady = false;
    final epoch = ++_epoch;
    complete = false;
    unavailable = false;
    return _enqueue(() async {
      await _player.stop();
      if (_disposed || epoch != _epoch) return;
      asset = null;
      position = Duration.zero;
      await _player.setPlaybackRate(speed);
      await _player.setVolume(1);
      await _player.setReleaseMode(ReleaseMode.stop);
      if (_disposed || epoch != _epoch) return;
      await _player.play(BytesSource(bytes, mimeType: mimeType));
      if (_disposed || epoch != _epoch) {
        await _player.stop();
        return;
      }
      _sourceReady = true;
      playing = true;
      _notify();
    });
  }

  Future<void> resume() {
    if (!_sourceReady && !_disposed && _restart != null) return _restart!();
    final epoch = ++_epoch;
    return _enqueue(() async {
      if (_disposed || epoch != _epoch || unavailable || !_sourceReady) return;
      await _player.resume();
      if (_disposed || epoch != _epoch) {
        await _player.pause();
        return;
      }
      playing = true;
      _notify();
    });
  }

  Future<void> setSpeed(double value) {
    speed = value;
    return _enqueue(() async {
      await _player.setPlaybackRate(value);
      _notify();
    });
  }

  Future<void> setVolume(double value) =>
      _enqueue(() => _player.setVolume(value.clamp(0.0, 1.0)));

  Future<void> stop() {
    ++_epoch;
    _restart = null;
    _sourceReady = false;
    playing = false;
    _notify();
    return _enqueue(() async {
      await _player.stop();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(
      _enqueue(() async {
        await _player.dispose();
      }),
    );
    super.dispose();
  }
}
