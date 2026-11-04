import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/audio/narration_speed.dart';

abstract interface class PrayerNarrationPlayer {
  Future<void> play(Uint8List bytes);
  Future<void> playText(String text);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> close();
}

class AudioplayersPrayerNarrationPlayer implements PrayerNarrationPlayer {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _usingDeviceVoice = false;
  String? _pausedText;

  @override
  Future<void> play(Uint8List bytes) async {
    await _tts.stop();
    _usingDeviceVoice = false;
    _pausedText = null;
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
  Future<void> playText(String text) async {
    final words = text.trim();
    if (words.isEmpty) return;
    await _player.stop();
    _usingDeviceVoice = true;
    _pausedText = words;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(defaultNarrationSpeed);
    await _tts.speak(words);
  }

  @override
  Future<void> stop() async {
    _pausedText = null;
    await _tts.stop();
    await _player.stop();
  }

  @override
  Future<void> pause() async {
    if (_usingDeviceVoice) {
      await _tts.stop();
      return;
    }
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    if (_usingDeviceVoice) {
      final text = _pausedText;
      if (text != null) await _tts.speak(text);
      return;
    }
    await _player.resume();
  }

  @override
  Future<void> close() async {
    await _tts.stop();
    await _player.dispose();
  }
}
