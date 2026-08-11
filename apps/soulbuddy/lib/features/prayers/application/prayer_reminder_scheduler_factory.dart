import 'browser_prayer_reminder_scheduler.dart'
    if (dart.library.io) 'native_prayer_reminder_scheduler.dart'
    as platform;
import 'prayer_reminder_scheduler.dart';

PrayerReminderScheduler createPrayerReminderScheduler() =>
    platform.createPrayerReminderScheduler();
