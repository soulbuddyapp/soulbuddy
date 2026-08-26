enum PrayerReminderAction { open, prayed, snoozeTenMinutes, dismiss }

enum ReminderNotificationKind { prayer, altar }

enum NotificationPermissionStatus { granted, denied, unsupported }

class PrayerReminderResponse {
  const PrayerReminderResponse({
    required this.reminderId,
    required this.occurrenceKey,
    required this.action,
    this.kind = ReminderNotificationKind.prayer,
  });

  final String reminderId;
  final String occurrenceKey;
  final PrayerReminderAction action;
  final ReminderNotificationKind kind;
}

class PrayerScheduledNotification {
  const PrayerScheduledNotification({
    required this.platformNotificationId,
    required this.reminderId,
    required this.occurrenceKey,
    required this.scheduledAtUtc,
    this.kind = ReminderNotificationKind.prayer,
  });

  final int platformNotificationId;
  final String reminderId;
  final String occurrenceKey;
  final DateTime scheduledAtUtc;
  final ReminderNotificationKind kind;
}

abstract interface class PrayerReminderScheduler {
  bool get supportsSystemNotifications;

  Stream<PrayerReminderResponse> get responses;

  Future<void> initialize();

  Future<bool> requestPermission();

  Future<NotificationPermissionStatus> permissionStatus();

  Future<void> showTestReminder();

  Future<void> schedule(PrayerScheduledNotification notification);

  Future<void> cancel(int platformNotificationId);
}
