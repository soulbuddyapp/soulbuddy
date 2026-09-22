import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/audio/narration_speed.dart';

abstract interface class PrayerNarrationPlayer {
  Future<void> play(Uint8List bytes);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> close();
}

class AudioplayersPrayerNarrationPlayer implements PrayerNarrationPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(Uint8List bytes) async {
    await _player.play(
      BytesSource(bytes, mimeType: 'audio/mpeg'),
      ctx: AudioContextConfig(
        respectSilence: true,
        stayAwake: false,
        focus: AudioContextConfigFocus.gain,
      ).build(),
    );
    await _player.setPlaybackRate(defaultNarrationSpeed);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> close() => _player.dispose();
}
