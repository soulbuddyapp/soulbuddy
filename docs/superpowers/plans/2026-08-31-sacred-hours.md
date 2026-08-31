# Sacred Hours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two configurable default Sacred Hours, a guided prayer-to-work session, curated original chimes, prayer/Person links, and dependable platform-aware reminders.

**Architecture:** Store Sacred Hour definitions and factual occurrences as owner-scoped PowerSync records while keeping notification delivery and exact-alarm permission state local to each installation. Reuse the existing notification scheduler through a new `sacredHour` kind, isolate Android exact-alarm access behind a capability service, and keep onboarding, Settings, Today, session, Prayer, Persons, and Remember connected through focused providers rather than direct SQL.

**Tech Stack:** Flutter 3.35/Dart 3.9, Riverpod, PowerSync SQLite, `flutter_local_notifications` 20.1, `timezone`, `audioplayers`, Laravel, MariaDB, Pest, Android/iOS local notifications.

---

## File map

### Flutter domain and persistence

- Create `apps/soulbuddy/lib/features/sacred_hours/domain/sacred_hour.dart` — validated hours, sound keys, reminder modes, drafts, occurrences, and local delivery values.
- Create `apps/soulbuddy/lib/features/sacred_hours/data/sacred_hour_repository.dart` — storage interface.
- Create `apps/soulbuddy/lib/features/sacred_hours/data/powersync_sacred_hour_repository.dart` — default seeding, CRUD, links, device rows, and occurrence writes.
- Create `apps/soulbuddy/lib/features/sacred_hours/providers/sacred_hour_providers.dart` — repositories, bootstrap, streams, actions, and session dependencies.
- Modify `apps/soulbuddy/lib/core/database/app_schema.dart` — two synced tables and one local-only delivery table.

### Scheduling and audio

- Create `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_reminder_coordinator.dart` — schedule/cancel/respond/fallback behavior.
- Create `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_alarm_permission.dart` and platform factories — exact-alarm capability and settings request.
- Create `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_sound_player.dart` — one-at-a-time sound preview.
- Modify the existing prayer scheduler contract and native/browser implementations to carry Sacred Hour sound and precision without creating another notification plugin wrapper.
- Create `tools/audio/generate_sacred_hour_chimes.dart` and generated assets/manifests for Flutter, Android raw resources, and iOS bundle resources.

### Presentation

- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hours_onboarding_page.dart`.
- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hours_settings_section.dart`.
- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_editor_sheet.dart`.
- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_sound_picker.dart`.
- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`.
- Create `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_today_card.dart`.
- Modify onboarding, Settings, Today, router, app bootstrap, and Remember capture entry points only where they consume those components.

### Laravel

- Create one migration, two models, and `ApplySacredHourMutation` for `sacred_hours` and `sacred_hour_occurrences`.
- Register both tables in the composite sync mutation pipeline and cover MariaDB-compatible constraints.

---

### Task 1: Sacred Hour domain and runtime schema

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/domain/sacred_hour.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/data/sacred_hour_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_domain_test.dart`
- Modify: `apps/soulbuddy/test/helpers/powersync_test_database.dart`

- [ ] **Step 1: Write failing tests for the exact domain contract.**

```dart
test('defaults are daily sixty-minute hours with fifteen minutes of prayer', () {
  final morning = SacredHour.defaultMorning(ownerId: ownerId, timezone: 'Africa/Lagos');
  expect(morning.purpose, SacredHourPurpose.morning);
  expect(morning.localTime, PrayerLocalTime(hour: 6, minute: 0));
  expect(morning.durationMinutes, 60);
  expect(morning.prayerMinutes, 15);
  expect(morning.sound, SacredHourSound.gentleChime);
  expect(morning.enabled, isTrue);
});

test('rejects unsupported prayer duration and mismatched prayer reference', () {
  expect(() => SacredHourDraft(name: 'Morning', localTime: PrayerLocalTime(hour: 6, minute: 0), timezone: 'UTC', prayerMinutes: 20), throwsArgumentError);
  expect(() => SacredHour.fromRow({...validRow, 'prayer_type': 'library', 'prayer_id': null}), throwsFormatException);
});
```

- [ ] **Step 2: Run `flutter test test/features/sacred_hours/sacred_hour_domain_test.dart` and confirm it fails because the types do not exist.**
- [ ] **Step 3: Implement these stable values and interfaces.**

```dart
enum SacredHourPurpose { morning, evening, custom }
enum SacredHourSound { gentleChime, dawnChime, stillBell, eveningChime, device, silent }
enum SacredHourReminderMode { ordinary, precise }
enum SacredHourOccurrenceStatus { due, begun, completed, dismissed }

abstract interface class SacredHourRepository {
  Stream<List<SacredHour>> watchActive();
  Stream<SacredHour?> watch(String id);
  Stream<SacredHour?> watchCurrentOrNext(DateTime nowUtc);
  Stream<List<SacredHourDelivery>> watchDeliveries();
  Future<List<SacredHour>> ensureDefaults({required String timezone});
  Future<SacredHour> save(SacredHourDraft draft, {String? id});
  Future<void> setEnabled(String id, bool enabled);
  Future<void> archive(String id);
  Future<void> updateDeviceDelivery(String id, SacredHourDeviceDraft draft);
  Future<void> markOccurrence(String id, DateTime dueAt, SacredHourOccurrenceStatus status);
}
```

- [ ] **Step 4: Add synced `sacred_hours` and `sacred_hour_occurrences`, plus local-only `sacred_hour_devices`, to `appSchema`. Use owner/time and device/due indexes and nullable link columns `prayer_type`, `prayer_id`, and `person_id`.**
- [ ] **Step 5: Re-run the domain test and schema-opening tests; confirm they pass.**
- [ ] **Step 6: Commit with `feat: define Sacred Hour domain and schema`.**

### Task 2: Idempotent local-first repository

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/data/powersync_sacred_hour_repository.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_repository_test.dart`

- [ ] **Step 1: Write failing PowerSync tests for deterministic defaults, replay, edits, archive, link ownership, overlap discovery, device isolation, and idempotent occurrences.**

```dart
test('seeds exactly one morning and evening across retries', () async {
  final repository = PowerSyncSacredHourRepository(database: db.powersync, ownerId: ownerId, deviceId: 'device-a');
  await repository.ensureDefaults(timezone: 'Africa/Lagos');
  await repository.ensureDefaults(timezone: 'Africa/Lagos');
  final hours = await repository.watchActive().first;
  expect(hours.map((item) => item.purpose), [SacredHourPurpose.morning, SacredHourPurpose.evening]);
  expect(hours.map((item) => item.localTime.wireValue), ['06:00', '22:00']);
});

test('same occurrence response is recorded once', () async {
  await repository.markOccurrence(hour.id, dueAt, SacredHourOccurrenceStatus.begun);
  await repository.markOccurrence(hour.id, dueAt, SacredHourOccurrenceStatus.begun);
  expect(await db.powersync.getAll('SELECT * FROM sacred_hour_occurrences'), hasLength(1));
});
```

- [ ] **Step 2: Run the focused repository test and confirm missing implementation failures.**
- [ ] **Step 3: Implement deterministic UUID-v5 IDs from `ownerId + sacred-hour:morning|evening`, transactional `INSERT OR IGNORE` seeding, validated CRUD, owner-scoped link checks, and deterministic occurrence IDs from `hourId + dueAtUtc`.**
- [ ] **Step 4: Store precise/ordinary mode, notification ID, next due instant, snooze, dismissal, and scheduled timezone only in `sacred_hour_devices`; never upload permission state.**
- [ ] **Step 5: Re-run repository tests and assert synced writes enter the PowerSync CRUD queue while device rows do not.**
- [ ] **Step 6: Commit with `feat: persist local-first Sacred Hours`.**

### Task 3: Laravel storage and sync validation

**Files:**
- Create: `services/api/database/migrations/2026_08_31_000000_create_sacred_hour_tables.php`
- Create: `services/api/app/Models/SacredHour.php`
- Create: `services/api/app/Models/SacredHourOccurrence.php`
- Create: `services/api/app/Domain/Sync/ApplySacredHourMutation.php`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Modify: `services/api/app/Domain/Sync/ApplyCompositeSyncMutation.php`
- Modify: `services/api/tests/Unit/MariaDbMigrationCompatibilityTest.php`
- Test: `services/api/tests/Feature/Sync/SacredHourMutationTest.php`

- [ ] **Step 1: Write failing Pest tests for table shape, same-batch default creation, idempotent replay, cross-owner prayer/Person rejection, supported sound keys, fixed duration, prayer-minute choices, deterministic occurrence uniqueness, and archive behavior.**

```php
it('accepts one owned Sacred Hour with a supported sound', function () {
    $user = User::factory()->create();
    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [sacredHourOperation('op-uuid', 'sacred_hours', 'hour-uuid', [
            'owner_id' => $user->public_id,
            'purpose_key' => 'morning',
            'name' => 'Morning',
            'local_time' => '06:00',
            'timezone' => 'Africa/Lagos',
            'duration_minutes' => 60,
            'prayer_minutes' => 15,
            'enabled' => true,
            'sound_key' => 'gentle_chime',
            'prayer_type' => null,
            'prayer_id' => null,
            'person_id' => null,
            'archived_at' => null,
        ])],
    ])->assertOk()->assertJsonPath('accepted', 1);
});
```

- [ ] **Step 2: Run `php artisan test tests/Feature/Sync/SacredHourMutationTest.php tests/Unit/MariaDbMigrationCompatibilityTest.php` and confirm unsupported-table failures.**
- [ ] **Step 3: Create MariaDB/SQLite-compatible tables with UUID keys, `user_id` ownership, nullable `purpose_key`, unique `(user_id, purpose_key)`, target indexes, foreign keys, and fixed-shape validation in the mutation handler. Only the defaults store `morning` or `evening`; custom hours store `NULL`, allowing multiple custom rows while preventing duplicate defaults.**
- [ ] **Step 4: Register `sacred_hours` and `sacred_hour_occurrences` in both sync pipelines. Validate personal prayers against the owner, library prayers against published/non-archived content, and Persons against the owner. Soft-delete hours by setting `archived_at` and `enabled=false`.**
- [ ] **Step 5: Run the focused tests and the complete Laravel suite.**
- [ ] **Step 6: Commit with `feat: sync Sacred Hour metadata`.**

### Task 4: Premium original chime pipeline

**Files:**
- Create: `tools/audio/generate_sacred_hour_chimes.dart`
- Create: `apps/soulbuddy/assets/audio/sacred_hours/ASSET-MANIFEST.md`
- Create generated WAV masters under `apps/soulbuddy/assets/audio/sacred_hours/`
- Create matching Android resources under `apps/soulbuddy/android/app/src/main/res/raw/`
- Create matching iOS resources under `apps/soulbuddy/ios/Runner/Sounds/`
- Modify: `apps/soulbuddy/ios/Runner.xcodeproj/project.pbxproj`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_audio_asset_test.dart`

- [ ] **Step 1: Write a failing asset contract test requiring four distinct original files, matching platform-copy hashes, RIFF/WAVE validity, 2–8 second duration, peak below clipping, non-silent RMS, manifest checksums, CC0 dedication, and no known Elbiblio hashes.**
- [ ] **Step 2: Run the asset test and confirm missing-file failures.**
- [ ] **Step 3: Implement a deterministic 44.1 kHz mono 16-bit generator using layered bell partials, per-partial exponential decay, soft attack, restrained room tail, DC removal, and conservative peak normalization. Render:**

```text
sacred_gentle_chime.wav
sacred_dawn_chime.wav
sacred_still_bell.wav
sacred_evening_chime.wav
```

- [ ] **Step 4: Generate additional audition candidates only through named definitions in the same script. Ship at most two extra candidates when they are clearly distinct after phone-speaker/headphone review; otherwise retain the approved four. Never copy the unaudited Elbiblio SFX.**
- [ ] **Step 5: Add an `ASSET-MANIFEST.md` containing semantic use, synthesis recipe/version, duration, peak, RMS, SHA-256, ownership, and the exact regeneration command. Copy identical bytes into Android raw and iOS bundle resources.**
- [ ] **Step 6: Run the asset test, audition every shipped tone through `audioplayers` on the connected phone at low/medium volume, and reject harsh transients, inaudibility, excessive decay, or confusing similarity.**
- [ ] **Step 7: Commit with `feat: add original Sacred Hour chimes`.**

### Task 5: Scheduler sound and exact-alarm capabilities

**Files:**
- Modify: `apps/soulbuddy/lib/features/prayers/application/prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/browser_prayer_reminder_scheduler.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_alarm_permission.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_alarm_permission_factory.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_alarm_permission_io.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_alarm_permission_web.dart`
- Modify: `apps/soulbuddy/android/app/src/main/AndroidManifest.xml`
- Test: `apps/soulbuddy/test/features/prayers/prayer_reminder_scheduler_test.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_alarm_permission_test.dart`

- [ ] **Step 1: Add failing scheduler tests proving Sacred Hour payload privacy, Begin/Snooze/Not now actions, selected raw sound, silent/device fallbacks, inexact default, exact mode only when requested, and decoding of `kind=sacredHour`.**
- [ ] **Step 2: Add failing capability tests for Android granted/denied request flow and unsupported iOS/web behavior.**
- [ ] **Step 3: Run both focused tests and confirm enum/interface failures.**
- [ ] **Step 4: Extend the common request without changing ordinary prayer behavior.**

```dart
enum ReminderNotificationKind { prayer, altar, person, sacredHour }
enum ReminderSchedulePrecision { ordinary, exact }

class PrayerScheduledNotification {
  // existing fields
  final String? soundKey;
  final ReminderSchedulePrecision precision;
}

abstract interface class SacredHourAlarmPermission {
  Future<ExactAlarmPermissionStatus> status();
  Future<bool> request();
}
```

- [ ] **Step 5: Map Sacred Hour sounds to versioned Android channel IDs and `RawResourceAndroidNotificationSound`; map iOS to bundled filenames; omit sound for Silent; use platform default for Device sound. Keep existing prayer channels unchanged.**
- [ ] **Step 6: Map exact requests to `AndroidScheduleMode.exactAllowWhileIdle`; add only `android.permission.SCHEDULE_EXACT_ALARM`. Call `requestExactAlarmsPermission()` in context. Do not add `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `showWhenLocked`, `turnScreenOn`, overlay permission, or a startup service.**
- [ ] **Step 7: Re-run scheduler/capability tests and existing prayer/Altar/Person reminder tests.**
- [ ] **Step 8: Commit with `feat: schedule platform-aware Sacred Hour alerts`.**

### Task 6: Reminder coordinator and response semantics

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_reminder_coordinator.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/providers/sacred_hour_providers.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_reminder_coordinator_test.dart`

- [ ] **Step 1: Write failing tests for daily wall-time scheduling, timezone/DST preservation, exact-to-ordinary fallback, sound key propagation, pause/archive cancellation, ten-minute snooze, Not now dismissal, open event, reboot-rescheduled delivery projection, and duplicate response idempotency.**
- [ ] **Step 2: Run the focused test and confirm missing coordinator failures.**
- [ ] **Step 3: Implement one coordinator subscription over `watchDeliveries()`. Schedule one repeating daily request per enabled hour, cancel disabled delivery IDs, and emit only `SacredHourOpened(hourId, occurrenceKey)` for Begin/open.**
- [ ] **Step 4: On precise mode, query exact-alarm status before scheduling. Persist fallback capability status locally and schedule ordinary delivery whenever permission is unavailable or scheduling throws a permission error.**
- [ ] **Step 5: Re-run tests and commit with `feat: coordinate Sacred Hour reminders`.**

### Task 7: Compact onboarding setup

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hours_onboarding_page.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify: `apps/soulbuddy/lib/features/onboarding/presentation/onboarding_gate.dart`
- Modify: `apps/soulbuddy/test/features/onboarding/onboarding_screen_test.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hours_onboarding_test.dart`

- [ ] **Step 1: Write failing widget tests for the approved teaching copy, 6–7am and 10–11pm defaults, 5/15/30-minute choices, direct time editing, Keep these hours, permission denial, exactly-once save, standard-phone no-scroll layout, and 200% accessible scrolling.**
- [ ] **Step 2: Run onboarding tests and confirm the fourth setup page is absent.**
- [ ] **Step 3: Add `SacredHoursOnboardingSelection` and one dedicated final page after the three existing scenes. Keep the two natural-slab time cards, compact teaching copy, and controls inside the normal 390×844 viewport.**
- [ ] **Step 4: Have `OnboardingGate` call `ensureDefaults`, apply changed times/prayer minutes transactionally, then request ordinary notification permission. Complete onboarding and enter Goal flow even when permission is denied. `Go to Today` skips the permission request but leaves idempotent defaults available through bootstrap.**
- [ ] **Step 5: Re-run onboarding, gate, compact viewport, and accessibility tests.**
- [ ] **Step 6: Commit with `feat: establish Sacred Hours during onboarding`.**

### Task 8: Settings, editor, links, and sound preview

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_sound_player.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hours_settings_section.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_editor_sheet.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_sound_picker.dart`
- Modify: `apps/soulbuddy/lib/features/settings/presentation/settings_screen.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hours_settings_test.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_sound_picker_test.dart`

- [ ] **Step 1: Write failing widget tests for list/add/edit/pause/archive, overlap confirmation, prayer duration, one prayer and/or Person attachment, six core sound choices, one-at-a-time preview, preview Stop, Silent, ordinary/precise mode status, denial fallback, Retry, and 200% text.**
- [ ] **Step 2: Run the focused tests and confirm missing-widget failures.**
- [ ] **Step 3: Render Sacred Hours before Sound & touch. Keep each collapsed row to name, time range, prayer minutes, sound, and enabled state; move secondary fields into the editor sheet.**
- [ ] **Step 4: Populate prayer choices from reviewed library prayers and saved personal prayers using `PrayerReference`; populate Person choices from `prayerPeopleProvider`. Store only IDs and never copy prayer bodies or Person names into Sacred Hour records.**
- [ ] **Step 5: Implement preview with a single `AudioPlayer`, stop before changing tone, moderate app gain, no autoplay, and disposal on sheet close. Respect the global in-app sound preference for previews while explaining that device notification sound is controlled separately.**
- [ ] **Step 6: Re-run settings, sound, prayer, Person, and Sound & touch tests.**
- [ ] **Step 7: Commit with `feat: manage Sacred Hours and chimes`.**

### Task 9: Guided Sacred Hour session and remembrance handoff

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/application/sacred_hour_session_controller.dart`
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_session_screen.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_session_test.dart`
- Modify: `apps/soulbuddy/test/app/app_navigation_test.dart`

- [ ] **Step 1: Write failing tests for `/sacred-hours/:id`, prayer-first phase, 5/15/30 timer display, attached prayer and Person actions, Quiet prayer, explicit I prayed, early continuation, the four work prompts, app-background return, and Speak/Write remembrance handoff.**
- [ ] **Step 2: Run focused tests and confirm route/controller failures.**
- [ ] **Step 3: Implement a two-phase controller with `beginPrayer`, `recordPrayer`, `continueToWork`, and `markDismissed`. Derive elapsed time from timestamps/clock rather than maintaining a background service. A timer reaching zero changes presentation only.**
- [ ] **Step 4: Record explicit prayer with `PrayerPracticeRepository.recordSession(..., idempotencyKey: occurrenceKey)` and Person prayer with `PersonRepository.recordPrayer`. Link resulting IDs to the Sacred Hour occurrence. Never mark prayer from audio playback or timer completion.**
- [ ] **Step 5: Add `Remember what I understood` routes to `/remember/capture?mode=write|speak&source=sacred-hour&person=<id>`. Present `What may God be teaching me here?` as the initial prompt, but store the result as the person's memory without a divine-message claim.**
- [ ] **Step 6: Re-run session/navigation/recording tests and commit with `feat: guide the Sacred Hour session`.**

### Task 10: Today and app lifecycle integration

**Files:**
- Create: `apps/soulbuddy/lib/features/sacred_hours/presentation/sacred_hour_today_card.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Test: `apps/soulbuddy/test/features/sacred_hours/sacred_hour_today_card_test.dart`
- Modify: `apps/soulbuddy/test/features/today/today_screen_test.dart`

- [ ] **Step 1: Write failing tests that Today shows only current-or-next, uses Prepare/Begin/Continue by state, removes past inactive hours, never says missed, and remains above the fold in compact empty/new-user states.**
- [ ] **Step 2: Write failing app tests proving notification taps route to the correct session and bootstrap seeds defaults before coordinating schedules.**
- [ ] **Step 3: Run focused tests and confirm missing provider/card/event wiring.**
- [ ] **Step 4: Watch `sacredHourBootstrapProvider` and `sacredHourReminderCoordinatorProvider` in `SoulBuddyApp`, listen for `SacredHourOpened`, and navigate to `/sacred-hours/:id?occurrence=<key>`. Add the compact Today card without adding a sixth navigation destination or permanent overlay.**
- [ ] **Step 5: Re-run Today, app navigation, product invariant, compact viewport, and accessibility tests.**
- [ ] **Step 6: Commit with `feat: surface the next Sacred Hour`.**

### Task 11: Full local verification and connected-device QA

**Files:**
- Modify only if verification exposes a test-proven defect.

- [ ] **Step 1: Run `dart format --output=none --set-exit-if-changed lib test` from `apps/soulbuddy`.**
- [ ] **Step 2: Run `flutter analyze` and the focused Sacred Hour, onboarding, settings, scheduler, Prayer, Person, Remember, Today, app-navigation, accessibility, and product-invariant tests.**
- [ ] **Step 3: Run the complete Flutter test suite and complete Laravel test suite.**
- [ ] **Step 4: Build Flutter web and an Android debug APK. Confirm release resource shrinking retains every Sacred Hour raw sound.**
- [ ] **Step 5: Install on the connected physical Android device. Verify fresh/default seeding with a cleared app-data test installation, existing-user bootstrap, time editing, every sound preview, ordinary notification, exact-alarm grant/deny/revoke, reboot rescheduling, lock-screen privacy, snooze/dismiss, session deep link, prayer/Person attachment, audio/written remembrance, and no overflow at large text.**
- [ ] **Step 6: Capture screenshots of onboarding, Settings, Today, notification, and session states into `.artifacts/sacred-hours/`; inspect them before accepting visual quality.**
- [ ] **Step 7: Commit only test-proven corrections with `fix: harden Sacred Hours on Android`.**

### Task 12: Production backend and sync verification

**Files:**
- Modify: `docs/deployment/sbuddy.elbiblio.com.md`
- Modify only deployment configuration discovered on the existing server; do not replace unrelated site configuration.

- [ ] **Step 1: Build a commit-addressed Laravel release archive excluding `.env`, `vendor`, logs, caches, Flutter audio masters, and local artifacts. Record its SHA-256.**
- [ ] **Step 2: Upload to `/var/www/soulbuddy/releases/<commit>/`, install production Composer dependencies, link the existing shared `.env` and storage, run `php artisan migrate --force`, rebuild caches, and atomically repoint `/var/www/soulbuddy/current`.**
- [ ] **Step 3: Verify MariaDB tables, indexes, constraints, existing site health, `/api/health`, authentication, and an owned Sacred Hour mutation against `https://sbuddy.elbiblio.com`.**
- [ ] **Step 4: Inspect the production PowerSync service/dashboard table rules. Add owner-bucket SELECTs for `sacred_hours` and `sacred_hour_occurrences` if the existing rules are explicit; if rules already cover owned tables generically, leave them unchanged and record that evidence in the deployment document.**
- [ ] **Step 5: On the physical device, create/edit an hour offline, reconnect, verify upload acceptance, then verify the same metadata downloads into a clean secondary client while `sacred_hour_devices` does not sync.**
- [ ] **Step 6: Update the deployment document with release path, commit, migration names, health output, PowerSync rule evidence, and rollback command. Commit with `docs: record Sacred Hours deployment`.**

### Task 13: Final integration and handoff

**Files:**
- Modify only if final verification exposes a regression.

- [ ] **Step 1: Run `git status --short`, `git diff --check`, Flutter analyze/tests/builds, Laravel tests, remote health checks, and the physical-device smoke checklist once more from the final commit.**
- [ ] **Step 2: Confirm no API key, PEM, `.env`, generated deployment archive, screenshot, user audio, or device identifier is staged.**
- [ ] **Step 3: Merge only if implementation ran in an isolated worktree, push `main`, and verify `origin/main` resolves to the tested commit.**
- [ ] **Step 4: Report shipped Sacred Hour behavior, actual sound palette after audition, platform limitations, test counts, production release path, device installation, and any intentionally deferred candidate sounds.**

---

## Scope guardrails

- Do not add streaks, spiritual scores, missed-hour warnings, celebratory confetti, or shame copy.
- Do not request full-screen intent, overlay, battery-optimization bypass, exact-alarm install-time privilege, or automatic UI launch at boot.
- Do not upload private audio, prayer bodies, Person names, memories, or prompt responses as notification payloads.
- Do not add a background service solely to keep an hour timer alive.
- Do not ship unaudited third-party sounds or Elbiblio files with unresolved provenance.
- Do not expand the visible sound palette beyond eight total choices, including Device sound and Silent.
