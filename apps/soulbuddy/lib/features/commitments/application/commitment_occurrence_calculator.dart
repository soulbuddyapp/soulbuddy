import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/commitment.dart';

class CommitmentOccurrenceCalculator {
  CommitmentOccurrenceCalculator() {
    timezone_data.initializeTimeZones();
  }

  DateTime? next(
    CommitmentMeditationPlan plan, {
    required DateTime after,
    String? timezoneName,
    int? weekday,
  }) {
    if (!plan.enabled) return null;
    validateCommitmentPlan(
      frequency: plan.frequency,
      weekdaysMask: plan.weekdaysMask,
      localTime: plan.localTime,
      timezone: plan.timezone,
      durationMinutes: plan.durationMinutes,
    );
    final location = tz.getLocation(timezoneName ?? plan.timezone);
    final local = tz.TZDateTime.from(after, location);
    final parts = plan.localTime.split(':');
    for (var day = 0; day <= 8; day++) {
      final date = DateTime.utc(local.year, local.month, local.day + day);
      if (weekday != null && date.weekday != weekday) continue;
      if (plan.frequency == CommitmentMeditationFrequency.selectedDays &&
          (plan.weekdaysMask! & (1 << (date.weekday - 1))) == 0) {
        continue;
      }
      final candidate = tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (candidate.isAfter(after)) return candidate.toUtc();
    }
    return null;
  }
}
