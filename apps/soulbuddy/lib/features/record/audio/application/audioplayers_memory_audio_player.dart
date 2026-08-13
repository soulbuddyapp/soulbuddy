import 'package:audioplayers/audioplayers.dart';

import '../data/audio_asset_store.dart';
import 'memory_audio_player.dart';

class AudioplayersMemoryAudioPlayerDriver implements MemoryAudioPlayerDriver {
  AudioplayersMemoryAudioPlayerDriver({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get durationChanges => _player.onDurationChanged;

  @override
  Stream<Duration> get positionChanges => _player.onPositionChanged;

  @override
  Stream<MemoryAudioDriverStatus> get statusChanges =>
      _player.onPlayerStateChanged.map(
        (state) => switch (state) {
          PlayerState.playing => MemoryAudioDriverStatus.playing,
          PlayerState.paused => MemoryAudioDriverStatus.paused,
          PlayerState.completed => MemoryAudioDriverStatus.completed,
          PlayerState.stopped ||
          PlayerState.disposed => MemoryAudioDriverStatus.stopped,
        },
      );

  @override
  Future<void> play(AudioPlaybackSource source) =>
      _player.play(switch (source) {
        FileAudioPlaybackSource(:final path) => DeviceFileSource(path),
        BytesAudioPlaybackSource(:final bytes, :final mimeType) => BytesSource(
          bytes,
          mimeType: mimeType,
        ),
      });

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
