import 'package:audio_service/audio_service.dart';

import 'spiritual_session.dart';
import 'spiritual_session_controller.dart';

/// Exposes recording controls without putting private titles on the lock screen.
class SystemPlaybackHandler extends BaseAudioHandler {
  SystemPlaybackHandler(this.controller) {
    controller.addListener(_update);
    _update();
  }

  final SpiritualSessionController controller;

  void _update() {
    final state = controller.state;
    final session = state.session;
    if (session == null || !session.supportsSystemPlayback) {
      mediaItem.add(null);
      playbackState.add(
        PlaybackState(processingState: AudioProcessingState.idle),
      );
      return;
    }
    mediaItem.add(
      MediaItem(
        id: 'voice-recording',
        title: 'Voice recording',
        duration: state.duration > Duration.zero ? state.duration : null,
      ),
    );
    final playing = state.status == SpiritualSessionStatus.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: {if (session.onSeek != null) MediaAction.seek},
        androidCompactActionIndices: const [0, 1],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: state.position,
      ),
    );
  }

  @override
  Future<void> play() => controller.resume();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> seek(Duration position) => controller.seek(position);
  @override
  Future<void> stop() => controller.close();

  void dispose() => controller.removeListener(_update);
}
