import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../domain/prayer_reminder.dart';

abstract interface class PrayerOccurrenceCalculator {
  DateTime? next(PrayerReminderSchedule schedule, {required DateTime afterUtc});
}

final class TimezonePrayerOccurrenceCalculator
    implements PrayerOccurrenceCalculator {
  const TimezonePrayerOccurrenceCalculator._();

  static bool _initialized = false;

  factory TimezonePrayerOccurrenceCalculator.initialize() {
    if (!_initialized) {
      timezone_data.initializeTimeZones();
      _initialized = true;
    }
    return const TimezonePrayerOccurrenceCalculator._();
  }

  @override
  DateTime? next(
    PrayerReminderSchedule schedule, {
    required DateTime afterUtc,
  }) {
    final boundary = afterUtc.toUtc();
    if (schedule.type == PrayerScheduleType.once) {
      final onceAt = schedule.onceAt!.toUtc();
      return onceAt.isAfter(boundary) ? onceAt : null;
    }

    final location = timezone.getLocation(schedule.timezone);
    final localBoundary = timezone.TZDateTime.from(boundary, location);
    for (var dayOffset = 0; dayOffset <= 8; dayOffset++) {
      final date = DateTime(
        localBoundary.year,
        localBoundary.month,
        localBoundary.day + dayOffset,
      );
      if (schedule.type == PrayerScheduleType.weekdays) {
        final weekdayBit = 1 << (date.weekday - 1);
        if ((schedule.weekdaysMask! & weekdayBit) == 0) {
          continue;
        }
      }
      final candidates = _wallTimeCandidates(
        location,
        date.year,
        date.month,
        date.day,
        schedule.localTime.hour,
        schedule.localTime.minute,
      );
      for (final candidate in candidates) {
        if (candidate.isAfter(boundary)) {
          return candidate;
        }
      }
    }
    throw StateError('No prayer occurrence found within one schedule week');
  }

  List<DateTime> _wallTimeCandidates(
    timezone.Location location,
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    final wallAsUtc = DateTime.utc(year, month, day, hour, minute);
    final offsets = <Duration>{
      for (final sampleHours in const [-24, -6, 0, 6, 24])
        timezone.TZDateTime.from(
          wallAsUtc.add(Duration(hours: sampleHours)),
          location,
        ).timeZoneOffset,
    };
    final candidates = <DateTime>{};
    for (final offset in offsets) {
      final candidate = wallAsUtc.subtract(offset);
      final local = timezone.TZDateTime.from(candidate, location);
      if (local.year == year &&
          local.month == month &&
          local.day == day &&
          local.hour == hour &&
          local.minute == minute) {
        candidates.add(candidate);
      }
    }

    if (candidates.isEmpty) {
      candidates.add(
        timezone.TZDateTime(location, year, month, day, hour, minute).toUtc(),
      );
    }
    final sorted = candidates.toList()..sort();
    return sorted;
  }
}
