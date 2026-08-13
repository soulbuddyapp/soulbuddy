import 'prayer_audio_environment.dart';
import 'prayer_audio_environment_web.dart'
    if (dart.library.io) 'prayer_audio_environment_io.dart'
    as platform;

PrayerAudioEnvironment createPrayerAudioEnvironment() =>
    platform.createPrayerAudioEnvironment();
