# Resilient Android Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make daily and weekday prayer notifications recur through Android while the app process is not running.

**Architecture:** The prayer coordinator maps the stored reminder schedule to `ReminderNotificationRecurrence` when scheduling with the platform. Android repeats the scheduled notification and the app resolves a received notification action against the reminder ID and currently due occurrence after launch. Existing Android boot receivers retain and restore the platform schedule.

**Tech Stack:** Flutter, Riverpod, flutter_local_notifications, Android AlarmManager, Dart tests.

---

### Task 1: Encode persisted prayer recurrence in the scheduler request

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_coordinator.dart:380-405`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_coordinator_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('daily reminders are registered as Android daily recurrences', () async {
  await coordinator.start();
  expect(scheduler.scheduled.single.recurrence,
      ReminderNotificationRecurrence.daily);
});

test('weekday reminders are registered as Android weekly recurrences', () async {
  repository.reminder = repository.reminderWithSchedule(
    PrayerReminderSchedule.weekdays(
      localTime: PrayerLocalTime(hour: 6, minute: 30),
      timezone: 'Africa/Lagos',
      weekdaysMask: 0b0010101,
    ),
  );
  await coordinator.start();
  expect(scheduler.scheduled.single.recurrence,
      ReminderNotificationRecurrence.weekly);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart`

Expected: the expected recurrence is `daily` or `weekly`, but the scheduler received `once`.

- [ ] **Step 3: Map the domain schedule to platform recurrence**

```dart
ReminderNotificationRecurrence _recurrenceFor(
  PrayerReminderSchedule schedule,
) => switch (schedule.type) {
  PrayerScheduleType.once => ReminderNotificationRecurrence.once,
  PrayerScheduleType.daily => ReminderNotificationRecurrence.daily,
  PrayerScheduleType.weekdays => ReminderNotificationRecurrence.weekly,
};
```

Pass `recurrence: _recurrenceFor(occurrence.reminder.schedule)` into `PrayerScheduledNotification`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart`

Expected: PASS.

### Task 2: Resolve actions from repeating notifications

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_coordinator.dart:240-290`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_coordinator_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('a repeating alarm action resolves the current due occurrence', () async {
  await coordinator.start();
  await coordinator.handlePlatformResponse(
    PrayerReminderResponse(
      reminderId: 'reminder-1',
      occurrenceKey: 'reminder-1@old-scheduled-time',
      action: PrayerReminderAction.prayed,
    ),
  );
  expect(repository.sessionRecords.single.occurrenceKey,
      repository.currentOccurrence.occurrenceKey);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart`

Expected: no session is recorded because the platform's recurring payload contains the initial occurrence key.

- [ ] **Step 3: Prefer the exact occurrence, then a current occurrence for recurring reminders**

```dart
DuePrayerOccurrence? _occurrenceFor(PrayerReminderResponse response) {
  final exact = _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
    (item) => item?.reminder.id == response.reminderId &&
        item?.occurrenceKey == response.occurrenceKey,
    orElse: () => null,
  );
  if (exact != null) return exact;
  return _occurrences.cast<DuePrayerOccurrence?>().firstWhere(
    (item) => item?.reminder.id == response.reminderId &&
        item?.reminder.schedule.type != PrayerScheduleType.once,
    orElse: () => null,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart`

Expected: PASS.

### Task 3: Verify Android recovery integration

**Files:**
- Verify: `apps/soulbuddy/android/app/src/main/AndroidManifest.xml`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart`

- [ ] **Step 1: Assert recurrence reaches the native request**

```dart
expect(client.requests.single.recurrence,
    ReminderNotificationRecurrence.daily);
```

- [ ] **Step 2: Run focused Dart tests**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart test/features/prayers/prayer_reminder_scheduler_test.dart`

Expected: PASS.

- [ ] **Step 3: Analyze and build the release app bundle**

Run: `flutter analyze && flutter build appbundle --release --build-number=6`

Expected: analyzer reports no issues and Gradle creates the AAB.

- [ ] **Step 4: Install and verify on device**

Run: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`

Expected: ADB reports `Success`; a daily test reminder remains after the app is swiped away.
