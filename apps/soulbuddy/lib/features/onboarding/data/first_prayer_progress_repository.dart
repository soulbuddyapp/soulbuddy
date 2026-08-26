import '../domain/first_prayer_progress.dart';

abstract interface class FirstPrayerProgressRepository {
  Future<FirstPrayerProgress?> load();
  Future<void> save(FirstPrayerProgress progress);
  Future<void> clear();
}
