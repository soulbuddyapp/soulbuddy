import '../domain/library_prayer.dart';
import '../domain/today_prayer.dart';

abstract interface class PrayerRepository {
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  });

  Stream<LibraryPrayer?> watchPrayer(String id);

  Future<void> setHelpful(String prayerId, {required bool value});

  Future<void> selectForToday(String prayerId, {required bool includeAction});

  Stream<TodayPrayer?> watchToday(DateTime localDate);

  Future<void> completeTodayAction(
    DateTime localDate, {
    required String expectedPrayerId,
    required bool value,
  });
}
