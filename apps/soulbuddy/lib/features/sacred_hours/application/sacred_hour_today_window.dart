import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../domain/sacred_hour.dart';

enum SacredHourTodayPhase { hidden, upcoming, active }

class SacredHourTodayWindow {
  const SacredHourTodayWindow({
    required this.phase,
    required this.startsAtUtc,
    required this.minutesUntil,
  });

  final SacredHourTodayPhase phase;
  final DateTime startsAtUtc;
  final int minutesUntil;

  static SacredHourTodayWindow classify(
    SacredHour hour,
    DateTime nowUtc, {
    Duration leadTime = const Duration(hours: 1),
  }) {
    timezone_data.initializeTimeZones();
    final instant = nowUtc.toUtc();
    final location = timezone.getLocation(hour.timezone);
    final localNow = timezone.TZDateTime.from(instant, location);
    final todayStart = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
      hour.localTime.hour,
      hour.localTime.minute,
    );
    final previousStart = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day - 1,
      hour.localTime.hour,
      hour.localTime.minute,
    );

    for (final start in [previousStart, todayStart]) {
      final end = start.add(Duration(minutes: hour.durationMinutes));
      if (!instant.isBefore(start.toUtc()) && instant.isBefore(end.toUtc())) {
        return SacredHourTodayWindow(
          phase: SacredHourTodayPhase.active,
          startsAtUtc: start.toUtc(),
          minutesUntil: 0,
        );
      }
    }

    final nextStart = todayStart.toUtc().isAfter(instant)
        ? todayStart
        : timezone.TZDateTime(
            location,
            localNow.year,
            localNow.month,
            localNow.day + 1,
            hour.localTime.hour,
            hour.localTime.minute,
          );
    final until = nextStart.toUtc().difference(instant);
    final upcoming = until <= leadTime;
    return SacredHourTodayWindow(
      phase: upcoming
          ? SacredHourTodayPhase.upcoming
          : SacredHourTodayPhase.hidden,
      startsAtUtc: nextStart.toUtc(),
      minutesUntil: (until.inSeconds + 59) ~/ 60,
    );
  }
}
