import 'prayer_reminder_scheduler.dart';

class BrowserPrayerReminderScheduler implements PrayerReminderScheduler {
  const BrowserPrayerReminderScheduler();

  @override
  bool get supportsSystemNotifications => false;

  @override
  Stream<PrayerReminderResponse> get responses => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(PrayerScheduledNotification notification) async {}

  @override
  Future<void> cancel(int platformNotificationId) async {}
}

PrayerReminderScheduler createPrayerReminderScheduler() =>
    const BrowserPrayerReminderScheduler();
