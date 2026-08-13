import 'package:flutter/services.dart';

import 'prayer_audio_environment.dart';
import 'prayer_narration_playback_policy.dart';

PrayerAudioEnvironment createPrayerAudioEnvironment() =>
    const _NativePrayerAudioEnvironment();

class _NativePrayerAudioEnvironment implements PrayerAudioEnvironment {
  const _NativePrayerAudioEnvironment();

  static const _channel = MethodChannel('app.soulbuddy/prayer_audio');

  @override
  Future<PrayerAudioRoute> currentRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('currentRoute');
      return switch (route) {
        'speaker' => PrayerAudioRoute.speaker,
        'headphones' => PrayerAudioRoute.headphones,
        'silent' => PrayerAudioRoute.silent,
        'doNotDisturb' => PrayerAudioRoute.doNotDisturb,
        _ => PrayerAudioRoute.unknown,
      };
    } catch (_) {
      return PrayerAudioRoute.unknown;
    }
  }

  @override
  Future<bool> interruptionsAllowed() async {
    try {
      return await _channel.invokeMethod<bool>('interruptionsAllowed') ?? false;
    } catch (_) {
      return false;
    }
  }
}
