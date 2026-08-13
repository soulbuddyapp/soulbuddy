import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

abstract interface class PrayerNarrationPlayer {
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> close();
}

class AudioplayersPrayerNarrationPlayer implements PrayerNarrationPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(Uint8List bytes) => _player.play(
    BytesSource(bytes, mimeType: 'audio/mpeg'),
    ctx: AudioContextConfig(
      respectSilence: true,
      stayAwake: false,
      focus: AudioContextConfigFocus.gain,
    ).build(),
  );

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> close() => _player.dispose();
}
