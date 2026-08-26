import '../domain/library_prayer.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_language.dart';
import '../domain/today_prayer.dart';

abstract interface class PrayerRepository {
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
    PrayerLanguagePreference? languagePreference,
  });

  Stream<LibraryPrayer?> watchPrayer(String id);

  Future<void> setHelpful(String prayerId, {required bool value});

  Future<void> selectForToday(
    PrayerReference prayer, {
    required bool includeAction,
  });

  Stream<TodayPrayer?> watchToday(DateTime localDate);

  Future<void> completeTodayAction(
    DateTime localDate, {
    required PrayerReference expectedPrayer,
    required bool value,
  });
}
