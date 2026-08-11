# Prayer Reminders and Private Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user schedule a private reminder for a saved personal prayer and record, undo, and quietly count exact-revision prayer sessions from the prayer detail, an in-app due card, or an actionable native notification.

**Architecture:** Add synchronized `prayer_reminders` and `prayer_sessions` records beside personal prayers, plus a local-only `prayer_reminder_devices` table that makes notification enablement installation-specific. A platform-neutral scheduling service calculates IANA-timezone occurrences and persists the next occurrence before a native Android/iOS adapter schedules a generic local notification; web and foreground use the same persisted occurrence to show a compact in-app card. All session writes are offline-first PowerSync writes, exact-revision-bound, occurrence-idempotent, owner-scoped on Laravel, and retractable for five minutes.

**Tech Stack:** Flutter 3.35.7, Dart 3.9.2, Riverpod 3, PowerSync/SQLite, `flutter_local_notifications` 20.1.0, `timezone` 0.10.1, `flutter_timezone` 5.1.0, Laravel 12, PHPUnit/Pest, Chrome integration tests, Android API 34 emulator.

---

## Scope and file map

This plan includes native Android/iOS local reminders and the foreground/browser fallback card. Authenticated Web Push is a separate delivery plan because it requires subscription storage, service-worker routing, revocation, and server jobs. Narration is a separate private-media plan. Moderated publication is a separate eligibility and review plan. The UI reserves no fake controls for those capabilities.

Create these focused Flutter units:

- `apps/soulbuddy/lib/features/prayers/domain/prayer_reminder.dart`: immutable reminder schedule and weekday-mask rules.
- `apps/soulbuddy/lib/features/prayers/domain/prayer_session.dart`: exact-revision confirmation and five-minute retraction state.
- `apps/soulbuddy/lib/features/prayers/data/prayer_practice_repository.dart`: storage contract.
- `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_practice_repository.dart`: transactional local-first implementation.
- `apps/soulbuddy/lib/features/prayers/application/prayer_occurrence_calculator.dart`: pure IANA timezone schedule calculation.
- `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`: notification permission/schedule/cancel abstraction.
- `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`: Android/iOS plugin adapter.
- `apps/soulbuddy/lib/features/prayers/application/browser_prayer_reminder_scheduler.dart`: no-notification browser adapter; persisted due-card state remains active.
- `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_coordinator.dart`: reconcile synced reminder, device opt-in, timezone, next occurrence, and notification responses.
- `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`: repository, scheduler, due occurrence, session count, and command providers.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_sheet.dart`: once/daily/weekdays and local-time editor.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_card.dart`: compact due surface with `I prayed this`, `Snooze 10 minutes`, and `Dismiss`.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_session_actions.dart`: detail-screen confirmation/count/Undo UI.

Create these Laravel units:

- `services/api/database/migrations/2026_08_11_000002_create_prayer_practice_tables.php`: relational schema and integrity constraints.
- `services/api/app/Models/PrayerReminder.php` and `PrayerSession.php`: private models and relationships.
- `services/api/app/Domain/Sync/ApplyPrayerPracticeMutation.php`: validation, ownership, immutability, idempotency, and mutation application.
- `services/api/tests/Feature/Sync/PrayerPracticeMutationTest.php`: schema and sync boundary tests.

## Fixed contracts

Use these wire values exactly:

```text
schedule_type: once | daily | weekdays
session source: reminder | manual
weekdays_mask: bit 0 Monday, bit 1 Tuesday, ... bit 6 Sunday
notification payload: {"reminder_id":"<uuid>","occurrence_key":"<reminder-id>@<UTC ISO-8601>"}
notification title: Prayer reminder
notification body: Time set aside for prayer
notification actions: PRAYED, SNOOZE_10, DISMISS
```

The payload contains no prayer title, body, revision ID, Encounter, Scripture, or user identifier. Native `PRAYED` uses `showsUserInterface: true`; the app opens, resolves the current revision from local storage, and performs the same repository command as the in-app card. There is no background-isolate database write and no `SYSTEM_ALERT_WINDOW` permission.

### Task 1: Add the Flutter storage contract

**Files:**
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_reminder.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_session.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_practice_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_practice_repository.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_practice_repository_test.dart`

- [ ] **Step 1: Write failing real-PowerSync tests for reminder persistence and device isolation**

Create tests that open `openTestDatabase`, seed one personal prayer/current revision, and express this API:

```dart
final repository = PowerSyncPrayerPracticeRepository(
  database: database.powersync,
  ownerId: ownerId,
  deviceId: deviceId,
  now: () => DateTime.utc(2026, 8, 11, 8),
  uuid: const Uuid(),
);
final reminder = await repository.saveReminder(
  personalPrayerId: prayerId,
  schedule: PrayerReminderSchedule.daily(
    localTime: const PrayerLocalTime(hour: 7, minute: 30),
    timezone: 'Africa/Lagos',
  ),
  enableOnThisDevice: true,
);
expect(await repository.watchReminder(prayerId).first, reminder);
expect(await repository.watchDevice(reminder.id).first, isNotNull);
expect(await database.powersync.getNextCrudTransaction(), isNotNull);
```

Add separate tests proving a disabled second device does not change the synchronized reminder, a replacement schedule updates one row, deleting archives/disables it, malformed weekday masks fail before a write, and every query is owner-scoped.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/features/prayers/prayer_practice_repository_test.dart`

Expected: compilation fails because the domain types/repository do not exist and `appSchema` has no reminder/session tables.

- [ ] **Step 3: Add exact schema columns and indexes**

Append synchronized tables and the local-only device table:

```dart
Table('prayer_reminders', [
  Column.text('owner_id'),
  Column.text('personal_prayer_id'),
  Column.text('schedule_type'),
  Column.text('local_time'),
  Column.text('timezone'),
  Column.text('once_at'),
  Column.integer('weekdays_mask'),
  Column.integer('enabled'),
  Column.text('created_at'),
  Column.text('updated_at'),
  Column.text('archived_at'),
], indexes: [
  Index('prayer_reminders_owner_prayer', [
    IndexedColumn('owner_id'),
    IndexedColumn('personal_prayer_id'),
  ]),
]),
Table.localOnly('prayer_reminder_devices', [
  Column.text('reminder_id'),
  Column.text('device_id'),
  Column.integer('enabled_on_device'),
  Column.text('next_occurrence_at'),
  Column.integer('platform_notification_id'),
  Column.text('scheduled_timezone'),
  Column.text('snoozed_until'),
  Column.text('dismissed_occurrence_key'),
  Column.text('updated_at'),
], indexes: [
  Index('prayer_reminder_devices_due', [
    IndexedColumn('device_id'),
    IndexedColumn('enabled_on_device'),
    IndexedColumn('next_occurrence_at'),
  ]),
]),
Table('prayer_sessions', [
  Column.text('owner_id'),
  Column.text('personal_prayer_id'),
  Column.text('prayer_revision_id'),
  Column.text('reminder_id'),
  Column.text('reminder_occurrence_key'),
  Column.text('source'),
  Column.text('occurred_at'),
  Column.text('local_date'),
  Column.text('timezone'),
  Column.text('device_id'),
  Column.text('retracted_at'),
], indexes: [
  Index('prayer_sessions_owner_revision', [
    IndexedColumn('owner_id'),
    IndexedColumn('prayer_revision_id'),
    IndexedColumn('retracted_at'),
  ]),
  Index('prayer_sessions_occurrence', [
    IndexedColumn('owner_id'),
    IndexedColumn('reminder_occurrence_key'),
  ]),
]),
```

- [ ] **Step 4: Implement immutable domain validation**

Define `PrayerScheduleType`, `PrayerLocalTime`, `PrayerReminderSchedule`, `PrayerReminder`, `PrayerReminderDevice`, and `PrayerSession`. Constructors must reject unknown IANA-zone-empty strings, `hour` outside 0-23, `minute` outside 0-59, `once` without `onceAt`, `daily` with `onceAt` or a mask, and `weekdays` without a mask in `1..127`. `PrayerSession.canRetract(at)` is true only when `retractedAt == null` and `at.toUtc()` is no later than `occurredAt.toUtc().add(const Duration(minutes: 5))`.

- [ ] **Step 5: Implement repository writes as small transactions**

Use this interface exactly:

```dart
abstract interface class PrayerPracticeRepository {
  Stream<PrayerReminder?> watchReminder(String personalPrayerId);
  Stream<PrayerReminderDevice?> watchDevice(String reminderId);
  Stream<List<DuePrayerOccurrence>> watchDue(DateTime atUtc);
  Stream<int> watchSessionCount(String revisionId);
  Future<PrayerReminder> saveReminder({
    required String personalPrayerId,
    required PrayerReminderSchedule schedule,
    required bool enableOnThisDevice,
  });
  Future<void> archiveReminder(String reminderId);
  Future<void> setDeviceEnabled(String reminderId, {required bool enabled});
  Future<void> updateDeviceSchedule({
    required String reminderId,
    required DateTime? nextOccurrenceAt,
    required int platformNotificationId,
    required String scheduledTimezone,
  });
  Future<void> snooze(String reminderId, DateTime untilUtc);
  Future<void> dismiss(String reminderId, String occurrenceKey);
  Future<PrayerSession> recordSession({
    required String personalPrayerId,
    required String revisionId,
    required String timezone,
    String? reminderId,
    String? occurrenceKey,
  });
  Future<void> retractSession(String sessionId);
}
```

Use UUIDv7 for reminders/manual sessions, UUIDv5 with namespace URL and the string `soulbuddy:reminder-device:<reminderId>:<deviceId>` for device rows, and UUIDv5 with `soulbuddy:prayer-session:<reminderId>:<occurrenceKey>` for reminder sessions. `recordSession` must re-read the owned personal prayer and require its current revision to equal `revisionId` inside the write transaction. Reminder-session insertion must return the existing same-ID row instead of producing duplicate confirmations.

- [ ] **Step 6: Run focused tests and commit**

Run: `dart format lib test && flutter test test/features/prayers/prayer_practice_repository_test.dart && flutter analyze`

Expected: all focused tests pass and analysis reports no issues.

Commit:

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/prayers/domain apps/soulbuddy/lib/features/prayers/data apps/soulbuddy/test/features/prayers/prayer_practice_repository_test.dart
git commit -m "feat: persist private prayer reminders and sessions"
```

### Task 2: Enforce reminder and session rules in Laravel

**Files:**
- Create: `services/api/database/migrations/2026_08_11_000002_create_prayer_practice_tables.php`
- Create: `services/api/app/Models/PrayerReminder.php`
- Create: `services/api/app/Models/PrayerSession.php`
- Modify: `services/api/app/Models/PersonalPrayer.php`
- Create: `services/api/app/Domain/Sync/ApplyPrayerPracticeMutation.php`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Test: `services/api/tests/Feature/Sync/PrayerPracticeMutationTest.php`

- [ ] **Step 1: Write failing schema, authorization, idempotency, and immutability tests**

Post mixed PowerSync operations through the existing authenticated sync endpoint. Assert:

```php
expect(Schema::hasColumns('prayer_reminders', [
    'id', 'user_id', 'personal_prayer_id', 'schedule_type', 'local_time',
    'timezone', 'once_at', 'weekdays_mask', 'enabled', 'created_at',
    'updated_at', 'archived_at',
]))->toBeTrue();
expect(Schema::hasColumns('prayer_sessions', [
    'id', 'user_id', 'personal_prayer_id', 'prayer_revision_id', 'reminder_id',
    'reminder_occurrence_key', 'source', 'occurred_at', 'local_date',
    'timezone', 'device_id', 'retracted_at',
]))->toBeTrue();
```

Cover valid once/daily/weekdays shapes, invalid cross-field shapes, ignored uploaded `owner_id`, foreign prayer/revision/reminder access returning the same inaccessible result as missing records, immutable session identity fields, retraction timestamp more than five minutes after occurrence, duplicate reminder occurrence idempotency, personal-prayer deletion cascade, and a transaction rollback when one operation in a batch is invalid.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `php artisan test tests/Feature/Sync/PrayerPracticeMutationTest.php`

Expected: failures for missing tables/models and unsupported sync tables.

- [ ] **Step 3: Create constrained relational schema**

Create `prayer_reminders` with UUID primary key, `user_id` cascade, `personal_prayer_id` cascade, `schedule_type`, five-character `local_time`, IANA `timezone` length 64, nullable `once_at`, nullable unsigned-small `weekdays_mask`, `enabled`, timestamps, and `archived_at`. Add one active reminder per user/prayer using a unique `(user_id, personal_prayer_id)` key and archive/update the existing row instead of creating history rows.

Create `prayer_sessions` with UUID primary key; user/prayer/revision cascade keys; nullable reminder `nullOnDelete`; occurrence/source/time/date/timezone/device/retraction columns; index `(user_id, prayer_revision_id, retracted_at)`; and a nullable unique `(user_id, reminder_occurrence_key)` constraint. Add SQLite triggers and PostgreSQL checks for schedule shape and session source shape, and test both SQL branches structurally.

- [ ] **Step 4: Implement a dedicated mutation boundary**

`ApplyPrayerPracticeMutation::supports()` accepts only `prayer_reminders` and `prayer_sessions`. Validation rules are:

```php
'prayer_reminders.put' => [
    'owner_id' => [], 'personal_prayer_id' => ['required', 'uuid'],
    'schedule_type' => ['required', 'in:once,daily,weekdays'],
    'local_time' => ['required', 'date_format:H:i'],
    'timezone' => ['required', 'timezone:all'],
    'once_at' => ['nullable', 'date'],
    'weekdays_mask' => ['nullable', 'integer', 'between:1,127'],
    'enabled' => ['required', 'boolean'],
    'created_at' => ['sometimes', 'date'], 'updated_at' => ['sometimes', 'date'],
    'archived_at' => ['nullable', 'date'],
],
'prayer_reminders.patch' => [
    'schedule_type' => ['sometimes', 'in:once,daily,weekdays'],
    'local_time' => ['sometimes', 'date_format:H:i'],
    'timezone' => ['sometimes', 'timezone:all'],
    'once_at' => ['sometimes', 'nullable', 'date'],
    'weekdays_mask' => ['sometimes', 'nullable', 'integer', 'between:1,127'],
    'enabled' => ['sometimes', 'boolean'],
    'updated_at' => ['sometimes', 'date'],
    'archived_at' => ['sometimes', 'nullable', 'date'],
],
'prayer_sessions.put' => [
    'owner_id' => [], 'personal_prayer_id' => ['required', 'uuid'],
    'prayer_revision_id' => ['required', 'uuid'],
    'reminder_id' => ['nullable', 'uuid'],
    'reminder_occurrence_key' => ['nullable', 'string', 'max:160'],
    'source' => ['required', 'in:reminder,manual'],
    'occurred_at' => ['required', 'date'], 'local_date' => ['required', 'date_format:Y-m-d'],
    'timezone' => ['required', 'timezone:all'], 'device_id' => ['required', 'string', 'max:120'],
    'retracted_at' => ['nullable', 'date'],
],
'prayer_sessions.patch' => ['retracted_at' => ['required', 'date']],
```

Allow reminder DELETE only with empty data and implement it as an owner-scoped archive; reject session DELETE and any session PATCH field other than `retracted_at`. Reject unknown keys and empty reminder PATCH data. Validate the final merged reminder shape for PATCH, not only the partial payload. Require reminder source to have both reminder fields and manual source to have neither. Require the revision to belong to the prayer and user. Require `retracted_at >= occurred_at` and `retracted_at <= occurred_at + 5 minutes`. Lock user first, then sorted personal-prayer IDs, then sorted reminder/session IDs. Treat same user/occurrence duplicate PUT as accepted replay only when its semantic fields match; otherwise return `conflict`.

- [ ] **Step 5: Wire the mutation class without weakening legacy ordering**

Add both tables to `ApplySyncMutation::TABLES`, collect them for `ApplyPrayerPracticeMutation::validate()`, and call its `apply()` inside the existing transaction after user and personal-prayer locks. Continue storing every accepted operation in `sync_operations`; keep uploaded ownership non-authoritative.

- [ ] **Step 6: Verify backend and commit**

Run:

```powershell
vendor\bin\pint
php artisan test tests/Feature/Sync/PrayerPracticeMutationTest.php tests/Feature/Sync/PersonalPrayerMutationTest.php
php artisan migrate:fresh --env=testing
composer validate --strict --no-check-publish
composer audit --locked
```

Expected: tests pass, migration succeeds on SQLite, Composer is valid, and audit reports no advisories.

Commit:

```powershell
git add services/api/database/migrations services/api/app/Models services/api/app/Domain/Sync services/api/tests/Feature/Sync/PrayerPracticeMutationTest.php
git commit -m "feat: sync private prayer practices"
```

### Task 3: Calculate timezone-safe occurrences

**Files:**
- Modify: `apps/soulbuddy/pubspec.yaml`
- Modify: `apps/soulbuddy/pubspec.lock`
- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_occurrence_calculator.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_occurrence_calculator_test.dart`

- [ ] **Step 1: Add failing pure scheduling tests**

Initialize the bundled timezone database and assert exact UTC results for:

```dart
expect(
  calculator.next(
    PrayerReminderSchedule.daily(
      localTime: const PrayerLocalTime(hour: 7, minute: 30),
      timezone: 'Africa/Lagos',
    ),
    afterUtc: DateTime.utc(2026, 8, 11, 6, 29),
  ),
  DateTime.utc(2026, 8, 11, 6, 30),
);
```

Add separate tests for equality advancing to the next day, selected weekdays crossing a week boundary, once returning null after firing, New York spring-forward normalization, New York fall-back returning the first future matching wall time, and a changed timezone preserving `HH:mm` rather than preserving the old UTC instant.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/features/prayers/prayer_occurrence_calculator_test.dart`

Expected: compilation fails because `PrayerOccurrenceCalculator` is missing.

- [ ] **Step 3: Pin compatible packages**

Add exact constraints:

```yaml
flutter_local_notifications: 20.1.0
timezone: 0.10.1
flutter_timezone: 5.1.0
```

Run: `flutter pub get`

`flutter_local_notifications` 20.1.0 supports Flutter 3.22+ and compileSdk 35; do not resolve to 22.x because that line requires Flutter 3.38.1. `timezone` 0.10.1 supports the workspace's Dart 3.9; 0.11.x requires Dart 3.10.

- [ ] **Step 4: Implement the pure calculator**

Expose:

```dart
abstract interface class PrayerOccurrenceCalculator {
  DateTime? next(PrayerReminderSchedule schedule, {required DateTime afterUtc});
}

final class TimezonePrayerOccurrenceCalculator
    implements PrayerOccurrenceCalculator {
  TimezonePrayerOccurrenceCalculator({required TzDatabase database});
}
```

Convert `afterUtc` into the schedule location, search at most eight local calendar dates, construct `TZDateTime(location, year, month, day, hour, minute)`, require the candidate UTC instant to be strictly after `afterUtc`, and select weekday bits with `1 << (candidate.weekday - 1)`. Once schedules return their stored UTC instant only while future.

- [ ] **Step 5: Verify and commit**

Run: `dart format lib test && flutter test test/features/prayers/prayer_occurrence_calculator_test.dart && flutter analyze`

Commit:

```powershell
git add apps/soulbuddy/pubspec.yaml apps/soulbuddy/pubspec.lock apps/soulbuddy/lib/features/prayers/application/prayer_occurrence_calculator.dart apps/soulbuddy/test/features/prayers/prayer_occurrence_calculator_test.dart
git commit -m "feat: calculate local prayer occurrences"
```

### Task 4: Add native scheduling behind a testable adapter

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler_factory.dart`
- Create: `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Create: `apps/soulbuddy/lib/features/prayers/application/browser_prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/android/app/build.gradle.kts`
- Modify: `apps/soulbuddy/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/soulbuddy/ios/Runner/AppDelegate.swift`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart`

- [ ] **Step 1: Write failing adapter contract tests with a fake plugin gateway**

Express this interface:

```dart
abstract interface class PrayerReminderScheduler {
  Stream<PrayerReminderResponse> get responses;
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule(PrayerScheduledNotification notification);
  Future<void> cancel(int platformNotificationId);
}
```

Assert scheduling uses the generic title/body, encodes only reminder/occurrence IDs, uses Android `inexactAllowWhileIdle`, declares `PRAYED` with `showsUserInterface: true`, declares `SNOOZE_10` and `DISMISS`, never starts audio, and maps launch/tap/action responses into domain events. Assert the browser implementation never requests permission and emits no native response.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/features/prayers/prayer_reminder_scheduler_test.dart`

Expected: compilation fails for missing scheduler types.

- [ ] **Step 3: Implement platform-neutral DTOs and conditional factory**

Use a conditional export based on `dart.library.html`. The browser scheduler is a real no-native-schedule implementation; it does not throw because the persisted due-card path is its supported delivery mechanism.

- [ ] **Step 4: Configure Android and iOS exactly once**

In Android Gradle enable multidex and core library desugaring, set Java/Kotlin 17, and add `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`. Add only `RECEIVE_BOOT_COMPLETED` and the three plugin receivers for scheduled notifications, reboot rescheduling, and actions. Do not add exact-alarm, full-screen-intent, draw-over-apps, or notification-listener permissions.

In `AppDelegate.swift`, set `UNUserNotificationCenter.current().delegate = self` before plugin registration so foreground notification callbacks are available. Permission remains deferred until the first enable action.

- [ ] **Step 5: Implement native scheduling**

Initialize `tz` once, set the local location from `FlutterTimezone.getLocalTimezone().identifier`, initialize Android with `@mipmap/ic_launcher` and Darwin categories, then call `zonedSchedule` with `DateTimeComponents.time` for daily, `DateTimeComponents.dayOfWeekAndTime` for each selected weekday using stable derived notification IDs, and a one-shot call for once/snooze. Cancel all IDs derived from a reminder before rescheduling it. Keep the payload JSON minimal and reject unexpected keys when decoding.

- [ ] **Step 6: Verify debug Android build and commit**

Run:

```powershell
dart format lib test
flutter test test/features/prayers/prayer_reminder_scheduler_test.dart
flutter analyze
flutter build apk --debug
```

Expected: tests and analysis pass; APK builds with desugaring and the manifest merger succeeds.

Commit:

```powershell
git add apps/soulbuddy/pubspec.* apps/soulbuddy/lib/features/prayers/application apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart apps/soulbuddy/android apps/soulbuddy/ios/Runner/AppDelegate.swift
git commit -m "feat: schedule private native prayer reminders"
```

### Task 5: Reconcile reminders, device opt-in, and timezone changes

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_coordinator.dart`
- Create: `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_coordinator_test.dart`

- [ ] **Step 1: Write failing coordinator tests**

Use an in-memory repository and fake scheduler. Prove:

- first device enable requests permission once and stores/schedules the next occurrence only when granted;
- denial leaves the synchronized reminder saved but the device disabled;
- a synced reminder on a second device remains unscheduled until explicit enablement;
- changed schedules cancel old platform IDs before scheduling new ones;
- app resume detects an OS timezone change, recalculates the same local wall time, persists `scheduled_timezone`, and emits one quiet confirmation;
- once schedules disable the local device row after their sole occurrence;
- `PRAYED`, snooze, dismiss, and ordinary-tap responses are occurrence-idempotent;
- dispose stops timers and subscriptions before the database closes.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/features/prayers/prayer_reminder_coordinator_test.dart`

Expected: compilation fails because coordinator/providers are missing.

- [ ] **Step 3: Implement one owner for lifecycle and timers**

`PrayerReminderCoordinator.start()` subscribes to enabled reminders/device rows and scheduler responses, reconciles serially, and arms one timer for the earliest local due occurrence. Bound timer waits to 15 minutes so wall-clock/timezone changes are detected even if lifecycle delivery is absent. Implement `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` as an immediate reconciliation signal. `dispose()` cancels the timer, awaits stream cancellations, and closes its event controller.

- [ ] **Step 4: Expose Riverpod providers without retaining family streams**

Use `FutureProvider` for repository/coordinator, `StreamProvider.autoDispose.family` for reminder/device/session count, and one app-root `prayerReminderCoordinatorProvider` watch. All retry helpers invalidate failed upstreams only; they must not tear down a healthy shared `appDatabaseProvider`.

- [ ] **Step 5: Verify and commit**

Run: `dart format lib test && flutter test test/features/prayers/prayer_reminder_coordinator_test.dart && flutter test && flutter analyze`

Commit:

```powershell
git add apps/soulbuddy/lib/app/app.dart apps/soulbuddy/lib/features/prayers/application/prayer_reminder_coordinator.dart apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart apps/soulbuddy/test/features/prayers/prayer_reminder_coordinator_test.dart
git commit -m "feat: reconcile prayer reminders per device"
```

### Task 6: Add the reminder editor and detail-screen session actions

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_sheet.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_session_actions.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/personal_prayer_detail_screen.dart`
- Test: `apps/soulbuddy/test/features/prayers/personal_prayer_practice_ui_test.dart`

- [ ] **Step 1: Write failing responsive widget tests**

At 390x844 and 1024x768, assert the saved prayer detail contains `Set reminder` and `I prayed this`; `Set reminder` opens a modal with Once/Every day/Selected days, a time picker control, weekday chips only for selected days, and one `Save reminder` action. Assert permission is requested only after save, validation uses short inline copy, and an existing schedule reopens populated.

Assert `I prayed this` records the displayed `currentRevisionId`, changes the quiet label to `1 prayer time recorded`, shows `Undo` for five minutes, and retracts the exact session. At 40 the label remains `40 prayer times recorded`; do not render rings, streaks, confetti, scores, or publish controls in this slice. Assert double taps during a pending write produce one repository call and errors use generic non-logging copy.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/features/prayers/personal_prayer_practice_ui_test.dart`

Expected: finders fail because the controls are absent.

- [ ] **Step 3: Implement minimal, choice-led UI**

Use segmented choices, weekday filter chips, and `showTimePicker`; avoid open-ended schedule text entry. Make controls at least 48 logical pixels, disable all conflicting actions during writes, and keep copy concise:

```text
Set reminder
Every day at 7:30 AM
I prayed this
14 prayer times recorded
Undo
Reminder saved on this device
```

The detail view reads the exact displayed `PersonalPrayer` value when invoking session commands so a stream update cannot cause a stale card to record a replacement revision.

- [ ] **Step 4: Verify accessibility and commit**

Run:

```powershell
dart format lib test
flutter test test/features/prayers/personal_prayer_practice_ui_test.dart
flutter test --dart-define=ACCESSIBILITY_TESTS=true test/features/prayers/personal_prayer_practice_ui_test.dart
flutter analyze
```

Expected: no overflow at 200% text scale, semantic button labels identify the prayer action, and tests pass at both sizes.

Commit:

```powershell
git add apps/soulbuddy/lib/features/prayers/presentation apps/soulbuddy/test/features/prayers/personal_prayer_practice_ui_test.dart
git commit -m "feat: add saved prayer reminders and confirmations"
```

### Task 7: Add the compact due card and notification response path

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_card.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_card_test.dart`

- [ ] **Step 1: Write failing card/action tests**

Pump the app with a due occurrence and assert a compact bottom card shows only the saved prayer title inside the unlocked app, plus `Open prayer`, `I prayed this`, `Snooze 10 minutes`, and `Dismiss`. Assert no automatic narration, no full-screen overlay, and no blockage of navigation. Prove each action passes the card's displayed prayer/revision/occurrence identity, duplicate `I prayed this` remains one session, snooze hides the card until the new due time, dismiss hides only that occurrence, and ordinary notification tap routes to `/prayers/saved/<id>`.

- [ ] **Step 2: Run and verify RED**

Run: `flutter test test/features/prayers/prayer_reminder_card_test.dart`

Expected: the due card and notification navigation path do not exist.

- [ ] **Step 3: Implement the compact host surface**

Attach the card through `MaterialApp.router.builder`, constrained to 520 pixels wide and safe-area padded. The card watches the earliest due occurrence and uses its immutable snapshot for actions. `Snooze 10 minutes` updates only local device state and reschedules a one-shot notification. `Dismiss` records the occurrence key and immediately schedules the next regular occurrence. `I prayed this` records the session, advances the reminder, and presents a five-second SnackBar Undo action.

- [ ] **Step 4: Verify and commit**

Run: `dart format lib test && flutter test test/features/prayers/prayer_reminder_card_test.dart && flutter test && flutter analyze`

Commit:

```powershell
git add apps/soulbuddy/lib/app apps/soulbuddy/lib/features/prayers/presentation/prayer_reminder_card.dart apps/soulbuddy/test/features/prayers/prayer_reminder_card_test.dart
git commit -m "feat: surface due prayer reminders"
```

### Task 8: Prove offline reopen, Chrome fallback, and Android notification behavior

**Files:**
- Create: `apps/soulbuddy/integration_test/prayer_reminder_flow_test.dart`
- Create: `apps/soulbuddy/integration_test/prayer_reminder_android_test.dart`
- Modify: `scripts/run_web_integration.ps1`
- Modify: `README.md`

- [ ] **Step 1: Write the integration flow before adjusting product code**

The cross-platform flow must:

1. open a seeded saved prayer;
2. create a daily reminder at a fake near-future local time;
3. assert one synchronized reminder and one local device row;
4. advance the injected clock until the compact card appears;
5. tap `I prayed this` twice and assert one exact-revision session;
6. tap Undo and assert `retracted_at` is set;
7. record a manual session from detail;
8. dispose the provider container and await the first database close;
9. open a fresh database/container at the same path and assert the schedule, device state, one active manual session, and one retracted reminder session survive.

The Android-specific flow additionally grants notification permission through ADB, schedules a near-future notification, backgrounds the app, asserts `Prayer reminder` appears with no title/body in `adb shell dumpsys notification`, invokes the `PRAYED` action, resumes the app, and asserts one session plus the next scheduled notification.

- [ ] **Step 2: Run the new targets and verify RED**

Run:

```powershell
flutter drive -d chrome --driver=test_driver/integration_test.dart --target=integration_test/prayer_reminder_flow_test.dart --headless --browser-dimension=390x844
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/prayer_reminder_android_test.dart
```

Expected: each test initially fails at its first missing or incorrect behavior; capture that exact failure before changing production code.

- [ ] **Step 3: Add the Chrome fallback target to the deterministic runner**

Append `integration_test/prayer_reminder_flow_test.dart` to `$targets` in `scripts/run_web_integration.ps1`. Keep stop-on-first-failure behavior and explicit database/container shutdown in every test; do not add retries or arbitrary reopen sleeps.

- [ ] **Step 4: Close every RED with the smallest production correction**

For each failure, add or strengthen a focused regression test first, reproduce RED, make one correction, and rerun the focused test before returning to the integration target. Do not relax notification privacy, exact-revision binding, permission timing, or idempotency assertions to make the tests pass.

- [ ] **Step 5: Document behavior and boundaries**

Add a concise README section covering private generic notification content, per-device enablement, timezone-preserving rescheduling, foreground/browser fallback, five-minute Undo, no streaks/scores, and the explicit absence of Web Push, narration, and publication from this release slice.

- [ ] **Step 6: Run full verification**

Run:

```powershell
scripts\verify.ps1
scripts\run_web_integration.ps1
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/prayer_reminder_android_test.dart
flutter build apk --debug
git diff --check
git status --short
```

Expected: format, analyze, all Flutter tests, web build, Composer validation/audit, Pint, all Laravel tests, all four Chrome flows, the Android API 34 reminder flow, and APK build pass. `git status --short` shows only intended slice files plus the user's pre-existing untracked `spiritual_wealth_app_framework.md`, which must remain unstaged.

- [ ] **Step 7: Commit the verified slice**

```powershell
git add README.md scripts/run_web_integration.ps1 apps/soulbuddy/integration_test/prayer_reminder_flow_test.dart apps/soulbuddy/integration_test/prayer_reminder_android_test.dart
git commit -m "test: verify private prayer reminders"
```

### Task 9: Security and quality review before merge

**Files:**
- Review: all changes from the feature branch base through HEAD

- [ ] **Step 1: Perform a privacy and ownership audit**

Verify notification payloads contain only reminder/occurrence IDs; Laravel derives ownership from authentication; all local queries include owner/device predicates; foreign and missing IDs are indistinguishable; sessions cannot be rebound to another revision; no logs contain prayer text; no secrets or API keys are present; and archived prayers cannot create new schedules or sessions.

- [ ] **Step 2: Perform a concurrency and lifecycle audit**

Verify stable lock ordering, duplicate occurrence replay, batch rollback, schedule replacement cancellation, app/database disposal ordering, no post-dispose timers, no repeated permission prompt, timezone-change deduplication, stale-card protection, and deterministic database reopen tests.

- [ ] **Step 3: Perform a UX/accessibility audit**

Verify 48-pixel targets, 200% text scaling, screen-reader action names, keyboard focus on web, no forced audio, no gamification language, compact non-blocking presentation, short option-led copy, and generic lock-screen content.

- [ ] **Step 4: Re-run evidence after review fixes**

Any discovered bug receives a failing regression test before its fix. After all review fixes, rerun `scripts\verify.ps1`, `scripts\run_web_integration.ps1`, the Android reminder integration target, `flutter build apk --debug`, `composer audit --locked`, and `git diff --check` from a clean committed state.

## Acceptance checklist

- A saved personal prayer can have one once/daily/weekday reminder at a local wall time.
- The creating installation is enabled only after permission succeeds; synced installations remain opt-in.
- Android/iOS notification content is generic and offline-actionable without exact-alarm or overlay permissions.
- Browser/foreground delivery shows a compact in-app card from persisted local state.
- A notification or card resolves the prayer's current revision when displayed and records that exact revision.
- Repeated confirmation for one occurrence creates one session; Undo retracts within five minutes.
- Detail-screen confirmation works without a reminder and the count is quiet and revision-specific.
- Timezone changes preserve local wall time, reschedule, and show one quiet confirmation.
- No narration, Web Push, publication, streak, score, ranking, confetti, or spiritual-value claim appears in this slice.
- All focused, full, Chrome, Android emulator, backend, migration, audit, analysis, and build checks pass.
