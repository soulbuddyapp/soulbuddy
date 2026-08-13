import 'prayer_audio_environment.dart';
import 'prayer_narration_playback_policy.dart';

PrayerAudioEnvironment createPrayerAudioEnvironment() =>
    const _WebPrayerAudioEnvironment();

class _WebPrayerAudioEnvironment implements PrayerAudioEnvironment {
  const _WebPrayerAudioEnvironment();

  @override
  Future<PrayerAudioRoute> currentRoute() async => PrayerAudioRoute.unknown;

  @override
  Future<bool> interruptionsAllowed() async => false;
}
