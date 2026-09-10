import '../../prayers/domain/library_prayer.dart';
import '../domain/sacred_hour.dart';

/// Ranks prayers for the character of a Sacred Hour without mutating them.
abstract final class SacredHourPrayerSuggestions {
  static PrayerPurpose primaryPurpose(SacredHour hour) =>
      _priorities(hour.purpose).first;

  static List<PrayerDisplay> forHour(
    SacredHour hour,
    Iterable<PrayerDisplay> prayers,
  ) {
    final priorities = _priorities(hour.purpose);
    final selected = hour.prayer;
    final candidates = prayers
        .where((prayer) => prayer.reference != selected)
        .toList(growable: false);
    candidates.sort((left, right) {
      final leftPriority = _priority(priorities, left.purpose);
      final rightPriority = _priority(priorities, right.purpose);
      if (leftPriority != rightPriority) return leftPriority - rightPriority;
      final leftPersonal = left.reference.source.name == 'personal' ? 0 : 1;
      final rightPersonal = right.reference.source.name == 'personal' ? 0 : 1;
      if (leftPersonal != rightPersonal) return leftPersonal - rightPersonal;
      return left.title.compareTo(right.title);
    });
    return candidates;
  }

  static List<PrayerPurpose> _priorities(SacredHourPurpose purpose) =>
      switch (purpose) {
        SacredHourPurpose.morning => const [
          PrayerPurpose.daily,
          PrayerPurpose.gratitude,
          PrayerPurpose.guidance,
        ],
        SacredHourPurpose.evening => const [
          PrayerPurpose.gratitude,
          PrayerPurpose.forgiveness,
          PrayerPurpose.difficultTime,
        ],
        SacredHourPurpose.custom => const [
          PrayerPurpose.daily,
          PrayerPurpose.guidance,
          PrayerPurpose.work,
        ],
      };

  static int _priority(List<PrayerPurpose> priorities, PrayerPurpose purpose) {
    final index = priorities.indexOf(purpose);
    return index == -1 ? priorities.length : index;
  }
}
