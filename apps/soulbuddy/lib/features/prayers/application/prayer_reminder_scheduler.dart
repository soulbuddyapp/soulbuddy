enum PrayerReminderAction { open, prayed, snoozeTenMinutes, dismiss }

class PrayerReminderResponse {
  const PrayerReminderResponse({
    required this.reminderId,
    required this.occurrenceKey,
    required this.action,
  });

  final String reminderId;
  final String occurrenceKey;
  final PrayerReminderAction action;
}

class PrayerScheduledNotification {
  const PrayerScheduledNotification({
    required this.platformNotificationId,
    required this.reminderId,
    required this.occurrenceKey,
    required this.scheduledAtUtc,
  });

  final int platformNotificationId;
  final String reminderId;
  final String occurrenceKey;
  final DateTime scheduledAtUtc;
}

abstract interface class PrayerReminderScheduler {
  Stream<PrayerReminderResponse> get responses;

  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> schedule(PrayerScheduledNotification notification);

  Future<void> cancel(int platformNotificationId);
}
