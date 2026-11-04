import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../data/audio_asset_store.dart';
import 'memory_audio_player.dart';

class AudioplayersMemoryAudioPlayerDriver implements MemoryAudioPlayerDriver {
  AudioplayersMemoryAudioPlayerDriver({
    AudioPlayer Function()? playerFactory,
    Future<bool> Function(bool)? setFocus,
  }) : _playerFactory = playerFactory ?? AudioPlayer.new,
       _setFocus = setFocus;

  final AudioPlayer Function() _playerFactory;
  final Future<bool> Function(bool)? _setFocus;
  Future<void> _focusTail = Future.value();
  int _focusEpoch = 0;
  final Map<String, AudioPlayer> _players = {};
  final Map<String, List<StreamSubscription<Object?>>> _subscriptions = {};
  final StreamController<Duration> _durations =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<MemoryAudioDriverStatus> _statuses =
      StreamController<MemoryAudioDriverStatus>.broadcast();
  String? _currentAssetId;

  AudioPlayer? get _current => _players[_currentAssetId];

  @override
  Stream<Duration> get durationChanges => _durations.stream;

  @override
  Stream<Duration> get positionChanges => _positions.stream;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges => _statuses.stream;

  @override
  Future<void> prepare(String assetId, AudioPlaybackSource source) async {
    if (_players.containsKey(assetId)) return;
    final player = _playerFactory();
    try {
      // Keep the prepared source attached after completion so the same memory
      // can be replayed without reopening its private bytes.
      await prepareVoicePlaybackPlayer(
        player,
        externalFocus: _setFocus != null,
      );
      await _setSource(player, source);
    } catch (_) {
      await player.dispose();
      rethrow;
    }
    _players[assetId] = player;
    _subscriptions[assetId] = [
      player.onDurationChanged.listen((value) {
        if (_currentAssetId == assetId) _durations.add(value);
      }),
      player.onPositionChanged.listen((value) {
        if (_currentAssetId == assetId) _positions.add(value);
      }),
      player.onPlayerStateChanged.listen((value) {
        if (_currentAssetId == assetId) {
          if (value == PlayerState.completed || value == PlayerState.stopped) {
            unawaited(_releaseFocus().catchError((Object _) {}));
          }
          _statuses.add(_status(value));
        }
      }),
    ];
  }

  @override
  Future<void> release(String assetId) async {
    if (_currentAssetId == assetId) {
      _currentAssetId = null;
    }
    final subscriptions = _subscriptions.remove(assetId) ?? const [];
    final player = _players.remove(assetId);
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await player?.dispose();
  }

  @override
  Future<void> play(String assetId, AudioPlaybackSource source) async {
    var player = _players[assetId];
    if (player == null) {
      await prepare(assetId, source);
      player = _players[assetId]!;
    }
    _currentAssetId = assetId;
    await _acquireFocus();
    try {
      await player.resume();
    } catch (_) {
      await _releaseFocus();
      rethrow;
    }
  }

  Future<void> _setSource(AudioPlayer player, AudioPlaybackSource source) =>
      player.setSource(switch (source) {
        FileAudioPlaybackSource(:final path) => DeviceFileSource(path),
        BytesAudioPlaybackSource(:final bytes, :final mimeType) => BytesSource(
          bytes,
          mimeType: mimeType,
        ),
      });

  @override
  Future<void> pause() async {
    await _current?.pause();
    await _releaseFocus();
  }

  @override
  Future<void> resume() async {
    await _acquireFocus();
    try {
      await _current?.resume();
    } catch (_) {
      await _releaseFocus();
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async => _current?.seek(position);

  @override
  Future<void> stop() async {
    await _current?.stop();
    await _releaseFocus();
  }

  @override
  Future<void> dispose() async {
    await _releaseFocus();
    for (final subscriptions in _subscriptions.values) {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _subscriptions.clear();
    await _positions.close();
    await _durations.close();
    await _statuses.close();
  }

  Future<void> _acquireFocus() {
    if (_setFocus == null) return Future.value();
    final epoch = ++_focusEpoch;
    return _queueFocus(() async {
      if (epoch == _focusEpoch && !await _setFocus(true)) {
        throw StateError('Audio focus unavailable.');
      }
    });
  }

  Future<void> _releaseFocus() {
    if (_setFocus == null) return Future.value();
    final epoch = _focusEpoch;
    return _queueFocus(() async {
      if (epoch == _focusEpoch) await _setFocus(false);
    });
  }

  Future<void> _queueFocus(Future<void> Function() action) {
    final operation = _focusTail.then((_) => action());
    _focusTail = operation.catchError((Object _) {});
    return operation;
  }
}

Future<void> prepareVoicePlaybackPlayer(
  AudioPlayer player, {
  bool externalFocus = false,
}) async {
  await player.setPlayerMode(PlayerMode.mediaPlayer);
  await player.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: externalFocus
            ? AndroidAudioFocus.none
            : AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
    ),
  );
  await player.setReleaseMode(ReleaseMode.stop);
}

MemoryAudioDriverStatus _status(PlayerState state) => switch (state) {
  PlayerState.playing => MemoryAudioDriverStatus.playing,
  PlayerState.paused => MemoryAudioDriverStatus.paused,
  PlayerState.completed => MemoryAudioDriverStatus.completed,
  PlayerState.stopped ||
  PlayerState.disposed => MemoryAudioDriverStatus.stopped,
};
