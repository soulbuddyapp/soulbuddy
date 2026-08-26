import '../domain/prayer_reminder.dart';
import '../domain/prayer_reference.dart';
import '../domain/prayer_session.dart';

abstract interface class PrayerPracticeRepository {
  Stream<PrayerReminder?> watchReminder(String personalPrayerId);
  Stream<PrayerReminderDevice?> watchDevice(String reminderId);
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc);
  Stream<int> watchSessionCount(String revisionId);
  Stream<bool> watchSessionForDate(
    PrayerReference prayer,
    DateTime localDate, {
    String? revisionId,
  });
  Future<int> getSessionCount(String revisionId);

  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  });

  Future<void> archiveReminder(String reminderId);
  Future<void> setDeviceEnabled(String reminderId, {required bool enabled});
  Future<void> saveNarrationPreference({
    required String reminderId,
    required bool consentAccepted,
    required bool autoplayWhenOpened,
    String? revisionId,
    List<int>? bytes,
    String? contentType,
  });

  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  });

  Future<void> snooze(String reminderId, DateTime untilUtc);
  Future<void> dismiss(String reminderId, String occurrenceKey);

  Future<PrayerSession> recordSession({
    required PrayerReference prayer,
    required String timezone,
    String? revisionId,
    String? reminderId,
    String? occurrenceKey,
    String? idempotencyKey,
  });

  Future<void> retractSession(String sessionId);
}
