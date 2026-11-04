import '../../record/audio/domain/memory_audio.dart';
import '../domain/library_prayer.dart';
import '../domain/personal_prayer.dart';

/// Saves an actual voice recording as a prayer, without a transcription or a
/// placeholder text revision. The recording remains on the current device.
abstract interface class RecordedPersonalPrayerRepository {
  Future<PersonalPrayer> create({
    required String title,
    required RecordedAudioDraft audio,
    PrayerPurpose purpose = PrayerPurpose.daily,
    PrayerGrounding grounding = PrayerGrounding.generalChristian,
  });
}
