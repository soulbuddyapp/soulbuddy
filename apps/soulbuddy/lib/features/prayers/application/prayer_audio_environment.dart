import 'prayer_narration_playback_policy.dart';

abstract interface class PrayerAudioEnvironment {
  Future<PrayerAudioRoute> currentRoute();
  Future<bool> interruptionsAllowed();
}
