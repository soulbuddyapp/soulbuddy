import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../data/audio_asset_store.dart';
import 'memory_audio_player.dart';

class AudioplayersMemoryAudioPlayerDriver implements MemoryAudioPlayerDriver {
  AudioplayersMemoryAudioPlayerDriver({AudioPlayer Function()? playerFactory})
    : _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
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
      await prepareVoicePlaybackPlayer(player);
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
    await player.resume();
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
  Future<void> pause() async => _current?.pause();

  @override
  Future<void> resume() async => _current?.resume();

  @override
  Future<void> seek(Duration position) async => _current?.seek(position);

  @override
  Future<void> stop() async => _current?.stop();

  @override
  Future<void> dispose() async {
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
}

Future<void> prepareVoicePlaybackPlayer(AudioPlayer player) async {
  await player.setPlayerMode(PlayerMode.mediaPlayer);
  await player.setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
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
