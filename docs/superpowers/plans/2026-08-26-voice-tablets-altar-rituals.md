# Voice Tablets and Altar Rituals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a person record a saved prayer in their own voice, optionally add a short Prayer Refrain, keep the Voice Tablet on their Altar as a daily ritual, play it offline, and explicitly confirm that they prayed.

**Architecture:** Extend the existing private audio capture/store rather than adding another recorder. Synchronize neutral Voice Tablet and Altar schedule metadata through the established PowerSync/Laravel mutation path, keep user audio bytes device-local, and project the next due ritual into Today. This first slice uses manual in-app playback; ambient mixing and notification-time recorded audio are deliberately separate follow-up plans.

**Tech Stack:** Flutter, Riverpod, PowerSync SQLite, `record`, `audioplayers`, Laravel 12, MariaDB, PHPUnit/Pest, Flutter widget/integration tests.

---

## Scope boundaries

This plan delivers a complete local-first ritual without ambient sound beds or custom notification sounds. It creates the correct data and UI seams for those later slices:

1. `2026-08-26-meditation-sound-beds.md` will add Stillness, Gentle Rain, Flowing Water, mixing, ducking, timed sessions, and optional prompts.
2. `2026-08-26-prayer-refrain-notification-audio.md` will add capability-checked iOS/Android notification derivatives and universal fallbacks.

No full-screen alarms, cloud audio upload, AI processing of recordings, autoplay over other apps, streaks, or play counts belong in this plan.

## File map

### Shared audio capture

- Modify `apps/soulbuddy/lib/features/record/audio/domain/memory_audio.dart` — introduce a reusable recorded-audio draft and configurable duration validation while preserving `MemoryAudio`.
- Modify `apps/soulbuddy/lib/features/record/audio/application/audio_capture_controller.dart` — accept a per-use maximum duration.
- Modify `apps/soulbuddy/lib/features/record/audio/presentation/audio_capture_panel.dart` — accept prayer-specific headings/copy without duplicating controls.
- Modify the corresponding tests under `apps/soulbuddy/test/features/record/`.

### Voice Tablets

- Create `apps/soulbuddy/lib/features/prayers/domain/voice_tablet.dart` — domain types, source identity, audio kind, and duration rules.
- Create `apps/soulbuddy/lib/features/prayers/data/voice_tablet_repository.dart` — repository contract.
- Create `apps/soulbuddy/lib/features/prayers/data/powersync_voice_tablet_repository.dart` — atomic local metadata and audio attachment implementation.
- Create `apps/soulbuddy/lib/features/prayers/providers/voice_tablet_providers.dart` — owner-scoped Riverpod wiring.
- Create `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_sheet.dart` — full prayer and optional refrain capture/review flow.
- Create `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart` — single-asset manual playback with explicit `I prayed`.
- Modify `apps/soulbuddy/lib/features/prayers/presentation/personal_prayer_detail_screen.dart` and `prayer_detail_screen.dart` — add `Record in my voice` entry points.

### Altar rituals

- Create `apps/soulbuddy/lib/features/altar/domain/altar_ritual.dart` — typed Altar target and schedule.
- Create `apps/soulbuddy/lib/features/altar/data/altar_ritual_repository.dart` — repository contract.
- Create `apps/soulbuddy/lib/features/altar/data/powersync_altar_ritual_repository.dart` — owned metadata, local device state, and next-due query.
- Create `apps/soulbuddy/lib/features/altar/providers/altar_ritual_providers.dart` — reactive Today projection.
- Create `apps/soulbuddy/lib/features/altar/presentation/altar_ritual_sheet.dart` — daily/weekday time setup and pause/edit/remove.
- Create `apps/soulbuddy/lib/features/altar/presentation/today_altar_card.dart` — compact due ritual card.
- Modify `apps/soulbuddy/lib/features/today/presentation/today_screen.dart` — place `At your Altar` inside the existing daily flow.

### Persistence and backend

- Modify `apps/soulbuddy/lib/core/database/app_schema.dart` — Voice Tablet, audio asset, Altar item/ritual, and device scheduling tables.
- Create `services/api/database/migrations/2026_08_26_000000_create_voice_tablet_altar_tables.php` — synchronized server metadata.
- Modify `services/api/app/Domain/Sync/ApplySyncMutation.php` — validate and apply the four synchronized record types.
- Create `services/api/tests/Feature/Sync/VoiceTabletAltarMutationTest.php` — ownership, replay, ordering, archive, and invalid reference coverage.
- Modify `apps/soulbuddy/test/helpers/powersync_test_database.dart` and backend compatibility tests for the new schema.

## Task 1: Generalize private audio capture and enforce refrain duration

**Files:**
- Modify: `apps/soulbuddy/lib/features/record/audio/domain/memory_audio.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/application/audio_capture_controller.dart`
- Modify: `apps/soulbuddy/lib/features/record/audio/presentation/audio_capture_panel.dart`
- Test: `apps/soulbuddy/test/features/record/audio_capture_controller_test.dart`
- Test: `apps/soulbuddy/test/features/record/audio_capture_panel_test.dart`

- [ ] **Step 1: Write failing controller tests for configurable limits**

Add tests proving a controller configured with `const Duration(seconds: 25)` stops at 25 seconds and the existing default still stops at 15 minutes:

```dart
test('stops a prayer refrain at its configured maximum', () async {
  final clock = FakeAudioElapsedClock()..elapsed = const Duration(seconds: 25);
  final recorder = FakeAudioRecorderGateway();
  final controller = AudioCaptureController(
    recorder: recorder,
    allocateTemporary: fakeTemporaryAudio,
    maximumDuration: const Duration(seconds: 25),
    elapsedClock: clock,
    tickerFactory: fakeTickerFactory,
  );

  await controller.start();
  capturedTick!();
  await pumpEventQueue();

  expect(recorder.stopCalls, 1);
  expect(controller.state.review!.duration, const Duration(seconds: 25));
});
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
flutter test test/features/record/audio_capture_controller_test.dart test/features/record/audio_capture_panel_test.dart
```

Expected: FAIL because `AudioCaptureController.maximumDuration` and panel copy overrides do not exist.

- [ ] **Step 3: Introduce a reusable draft and injected duration limit**

In `memory_audio.dart`, rename the draft to `RecordedAudioDraft` and retain a temporary compatibility alias while existing encounter code is migrated in this task:

```dart
const maximumPrivateAudioDuration = Duration(minutes: 15);
const maximumPrayerRefrainDuration = Duration(seconds: 25);

class RecordedAudioDraft {
  RecordedAudioDraft({
    required String temporaryKey,
    required String mimeType,
    required Duration duration,
    required List<double> waveform,
    Duration maximumDuration = maximumPrivateAudioDuration,
  }) : temporaryKey = _requiredText(temporaryKey, 'temporaryKey', 1024),
       mimeType = _audioMimeType(mimeType),
       duration = _duration(duration, maximumDuration),
       waveform = List.unmodifiable(_waveform(waveform));

  final String temporaryKey;
  final String mimeType;
  final Duration duration;
  final List<double> waveform;
}
```

Update `AudioCaptureController`:

```dart
AudioCaptureController({
  required AudioRecorderGateway recorder,
  required Future<TemporaryAudio> Function() allocateTemporary,
  this.maximumDuration = maximumPrivateAudioDuration,
  AudioElapsedClock? elapsedClock,
  AudioCaptureTickerFactory? tickerFactory,
}) : assert(maximumDuration > Duration.zero),
     _recorder = recorder,
     _allocateTemporary = allocateTemporary,
     _elapsedClock = elapsedClock ?? StopwatchAudioElapsedClock(),
     _tickerFactory = tickerFactory ?? _createTimerTicker;

final Duration maximumDuration;
```

Use `maximumDuration` in `_boundedElapsed`, the ticker stop condition, and the review draft:

```dart
final review = RecordedAudioDraft(
  temporaryKey: result.locator,
  mimeType: result.mimeType,
  duration: elapsed,
  waveform: _reviewWaveform(),
  maximumDuration: maximumDuration,
);
```

Change repository and form call sites from `MemoryAudioDraft` to `RecordedAudioDraft` in the same commit.

Add optional `heading`, `description`, `startLabel`, and `writeInsteadLabel` constructor values to `AudioCapturePanel`; preserve the current encounter defaults.

- [ ] **Step 4: Format and rerun tests**

Run:

```powershell
dart format lib/features/record/audio test/features/record
flutter test test/features/record/audio_capture_controller_test.dart test/features/record/audio_capture_panel_test.dart test/features/record/memory_audio_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/record/audio apps/soulbuddy/test/features/record
git commit -m "refactor: reuse private audio capture for prayer refrains"
```

## Task 2: Add Voice Tablet domain and local-first persistence

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/domain/voice_tablet.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/voice_tablet_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_voice_tablet_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Test: `apps/soulbuddy/test/features/prayers/voice_tablet_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover personal and library prayer sources, exact personal revision ownership, one current full recording, optional 25-second refrain, replacement without premature deletion, archive, and missing local audio:

```dart
test('attaches full and refrain assets to the exact owned prayer revision', () async {
  final tablet = await repository.create(
    source: VoiceTabletSource.personal(
      prayerId: personalPrayerId,
      revisionId: revisionId,
    ),
    title: 'Morning surrender',
    fullRecording: fullDraft,
    fullDurableAsset: fullAsset,
    refrain: refrainDraft,
    refrainDurableAsset: refrainAsset,
  );

  expect(tablet.source.revisionId, revisionId);
  expect(tablet.fullAudio?.duration, const Duration(minutes: 2));
  expect(tablet.refrainAudio?.duration, const Duration(seconds: 20));
  expect(await repository.watch(tablet.id).first, tablet);
});
```

Also assert a 26-second refrain throws `ArgumentError`, another owner's prayer throws `StateError`, and replacing a take returns old storage keys only after the new transaction commits.

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
flutter test test/features/prayers/voice_tablet_repository_test.dart
```

Expected: FAIL because the domain and repository do not exist.

- [ ] **Step 3: Define focused domain types**

Create:

```dart
enum VoiceTabletSourceType { personalPrayer, libraryPrayer }
enum VoiceTabletAudioKind { fullPrayer, refrain }

final class VoiceTabletSource {
  const VoiceTabletSource._({
    required this.type,
    required this.prayerId,
    this.revisionId,
  });

  factory VoiceTabletSource.personal({
    required String prayerId,
    required String revisionId,
  }) => VoiceTabletSource._(
    type: VoiceTabletSourceType.personalPrayer,
    prayerId: prayerId,
    revisionId: revisionId,
  );

  factory VoiceTabletSource.library({required String prayerId}) =>
      VoiceTabletSource._(
        type: VoiceTabletSourceType.libraryPrayer,
        prayerId: prayerId,
      );

  final VoiceTabletSourceType type;
  final String prayerId;
  final String? revisionId;
}

final class VoiceTabletAudio {
  const VoiceTabletAudio({
    required this.id,
    required this.kind,
    required this.storageKey,
    required this.mimeType,
    required this.duration,
    required this.byteSize,
    required this.waveform,
    required this.createdAt,
  });

  final String id;
  final VoiceTabletAudioKind kind;
  final String storageKey;
  final String mimeType;
  final Duration duration;
  final int byteSize;
  final List<double> waveform;
  final DateTime createdAt;

  void validateDuration() {
    final maximum = kind == VoiceTabletAudioKind.refrain
        ? maximumPrayerRefrainDuration
        : maximumPrivateAudioDuration;
    if (duration <= Duration.zero || duration > maximum) {
      throw ArgumentError.value(duration, 'duration');
    }
  }
}

final class VoiceTablet {
  const VoiceTablet({
    required this.id,
    required this.ownerId,
    required this.source,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.fullAudio,
    this.refrainAudio,
    this.archivedAt,
  });

  final String id;
  final String ownerId;
  final VoiceTabletSource source;
  final String title;
  final VoiceTabletAudio? fullAudio;
  final VoiceTabletAudio? refrainAudio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}
```

- [ ] **Step 4: Add PowerSync tables**

Add synchronized neutral metadata and local-only byte references:

```dart
Table('voice_tablets', [
  Column.text('owner_id'),
  Column.text('source_type'),
  Column.text('personal_prayer_id'),
  Column.text('library_prayer_id'),
  Column.text('prayer_revision_id'),
  Column.text('title'),
  Column.text('full_audio_id'),
  Column.text('refrain_audio_id'),
  Column.text('recording_device_id'),
  Column.text('created_at'),
  Column.text('updated_at'),
  Column.text('archived_at'),
]),
Table.localOnly('voice_tablet_audio_assets', [
  Column.text('owner_id'),
  Column.text('voice_tablet_id'),
  Column.text('audio_kind'),
  Column.text('storage_key'),
  Column.text('mime_type'),
  Column.integer('duration_ms'),
  Column.integer('byte_size'),
  Column.text('waveform_json'),
  Column.text('created_at'),
]),
```

Use a unique logical constraint in repository transactions: one active row per `(owner_id, voice_tablet_id, audio_kind)`.

- [ ] **Step 5: Implement atomic repository operations**

Define:

```dart
abstract interface class VoiceTabletRepository {
  Stream<VoiceTablet?> watch(String id);
  Stream<VoiceTablet?> watchForSource(VoiceTabletSource source);
  Future<VoiceTablet> create(VoiceTabletCreateRequest request);
  Future<VoiceTabletReplacement> replaceAudio(
    String tabletId,
    VoiceTabletAudioKind kind,
    RecordedAudioDraft draft,
    DurableAudio durable,
  );
  Future<List<String>> archive(String tabletId);
  Future<Set<String>> ownedStorageKeys();
}
```

`create` must verify the selected prayer exists, is active, and is owned where applicable; insert metadata and local asset rows in one database transaction; and return only after both succeed. `replaceAudio` inserts the new asset, updates the current ID, removes the prior local metadata, commits, and then returns the prior durable key for byte deletion. Never delete bytes inside the database transaction.

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
dart format lib/features/prayers/domain lib/features/prayers/data test/features/prayers/voice_tablet_repository_test.dart
flutter test test/features/prayers/voice_tablet_repository_test.dart test/core/database/app_database_sync_test.dart
```

Expected: PASS.

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/prayers/domain/voice_tablet.dart apps/soulbuddy/lib/features/prayers/data apps/soulbuddy/test/features/prayers/voice_tablet_repository_test.dart apps/soulbuddy/test/core/database/app_database_sync_test.dart
git commit -m "feat: add local-first voice tablets"
```

## Task 3: Add synchronized Voice Tablet and Altar metadata to Laravel

**Files:**
- Create: `services/api/database/migrations/2026_08_26_000000_create_voice_tablet_altar_tables.php`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Create: `services/api/tests/Feature/Sync/VoiceTabletAltarMutationTest.php`
- Modify: `services/api/tests/Unit/MariaDbMigrationCompatibilityTest.php`

- [ ] **Step 1: Write failing sync tests**

Use the existing sync-operation fixture pattern to prove:

```php
it('accepts an owned voice tablet and rejects another users prayer', function () {
    $owned = syncOperation('voice_tablets', 'put', $tabletId, [
        'owner_id' => $this->user->id,
        'source_type' => 'personal_prayer',
        'personal_prayer_id' => $this->prayer->id,
        'library_prayer_id' => null,
        'prayer_revision_id' => $this->revision->id,
        'title' => 'Morning surrender',
        'full_audio_id' => $fullAudioId,
        'refrain_audio_id' => null,
        'recording_device_id' => $this->deviceId,
        'created_at' => now()->toISOString(),
        'updated_at' => now()->toISOString(),
        'archived_at' => null,
    ]);

    $this->postJson('/api/v1/sync/mutations', ['operations' => [$owned]])
        ->assertOk();
});
```

Add cases for exclusive personal/library source columns, exact current/owned revision, immutable owner/source on patch, Altar target ownership, ritual-to-item ownership, valid local time/timezone/weekdays, replay idempotence, archive order, and deletion restrictions.

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
Set-Location C:\dev\soulbuddy\services\api
php artisan test tests/Feature/Sync/VoiceTabletAltarMutationTest.php
```

Expected: FAIL because tables and mutation validators do not exist.

- [ ] **Step 3: Create MariaDB-compatible tables**

The migration creates `voice_tablets`, `altar_items`, and `altar_rituals`. Audio bytes and local asset rows are not server tables. Required constraints:

```php
$table->uuid('id')->primary();
$table->foreignUuid('owner_id')->constrained('users');
$table->enum('source_type', ['personal_prayer', 'library_prayer']);
$table->uuid('personal_prayer_id')->nullable();
$table->uuid('library_prayer_id')->nullable();
$table->uuid('prayer_revision_id')->nullable();
$table->string('title', 120);
$table->uuid('full_audio_id')->nullable();
$table->uuid('refrain_audio_id')->nullable();
$table->uuid('recording_device_id');
$table->timestampsTz();
$table->timestampTz('archived_at')->nullable();
```

`altar_items` has `target_type`, nullable encounter/prayer/Voice Tablet IDs, and exactly one matching target. `altar_rituals` has `altar_item_id`, `schedule_type`, `local_time`, `timezone`, nullable `weekdays_mask`, `playback_mode`, `enabled`, timestamps, and `archived_at`. Enforce cross-column rules in `ApplySyncMutation` before writes so MariaDB and SQLite behavior remain deterministic.

- [ ] **Step 4: Extend validation and ordered application**

Add the new record types to the same pre-validation and transaction used by existing prayers. Apply dependency order:

```text
voice_tablets -> altar_items -> altar_rituals
```

Archive/delete order is the reverse. Validate references with the authenticated user's ownership, not client-supplied `owner_id`. Keep immutable target/source fields out of patch allowlists.

- [ ] **Step 5: Run Laravel checks and commit**

Run:

```powershell
php artisan test tests/Feature/Sync/VoiceTabletAltarMutationTest.php tests/Unit/MariaDbMigrationCompatibilityTest.php
vendor/bin/pint --test
composer audit --no-interaction
```

Expected: all tests PASS, Pint reports no changes required, and Composer reports no known vulnerabilities.

```powershell
git add services/api/database/migrations/2026_08_26_000000_create_voice_tablet_altar_tables.php services/api/app/Domain/Sync/ApplySyncMutation.php services/api/tests
git commit -m "feat(api): sync voice tablets and altar rituals"
```

## Task 4: Add Altar ritual domain and repository

**Files:**
- Create: `apps/soulbuddy/lib/features/altar/domain/altar_ritual.dart`
- Create: `apps/soulbuddy/lib/features/altar/data/altar_ritual_repository.dart`
- Create: `apps/soulbuddy/lib/features/altar/data/powersync_altar_ritual_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Test: `apps/soulbuddy/test/features/altar/altar_ritual_repository_test.dart`

- [ ] **Step 1: Write failing domain/repository tests**

Prove daily/weekday schedules, one local time, enabled/paused/archive behavior, typed Voice Tablet target, next-due selection, timezone wall-time preservation, and missing-local-audio projection.

```dart
test('returns only the next due enabled altar ritual', () async {
  await repository.save(dailyAt(hour: 7, minute: 0, tabletId: firstId));
  await repository.save(dailyAt(hour: 8, minute: 0, tabletId: secondId));

  final due = await repository.watchNextForDate(
    DateTime(2026, 8, 26),
    now: DateTime(2026, 8, 26, 7, 5),
  ).first;

  expect(due!.item.targetId, firstId);
  expect(due.localStatus, AltarRitualLocalStatus.due);
});
```

- [ ] **Step 2: Run and verify failure**

Run:

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
flutter test test/features/altar/altar_ritual_repository_test.dart
```

Expected: FAIL because the feature does not exist.

- [ ] **Step 3: Define schedule and playback types**

```dart
enum AltarTargetType { encounter, personalPrayer, libraryPrayer, voiceTablet }
enum AltarScheduleType { daily, weekdays }
enum AltarPlaybackMode { refrain, fullPrayer, openQuietly }

final class AltarRitualSchedule {
  AltarRitualSchedule.daily({
    required this.localTime,
    required this.timezone,
  }) : type = AltarScheduleType.daily,
       weekdaysMask = null;

  AltarRitualSchedule.weekdays({
    required this.localTime,
    required this.timezone,
    required int weekdaysMask,
  }) : type = AltarScheduleType.weekdays,
       weekdaysMask = validateWeekdaysMask(weekdaysMask);
}
```

Reuse `PrayerLocalTime` and the existing occurrence calculator rules instead of introducing a second timezone parser.

- [ ] **Step 4: Add synchronized and local device tables**

Add `altar_items` and `altar_rituals` matching Laravel. Add local-only `altar_ritual_devices` with `ritual_id`, `device_id`, `enabled_on_device`, `next_occurrence_at`, `platform_notification_id`, `scheduled_timezone`, `snoozed_until`, `dismissed_occurrence_key`, and `updated_at`.

The first slice does not schedule a system notification; it still persists deterministic device state so the reminder-audio plan can extend it without migration churn.

- [ ] **Step 5: Implement repository behavior**

```dart
abstract interface class AltarRitualRepository {
  Stream<AltarRitual?> watchForTarget(AltarTarget target);
  Stream<DueAltarRitual?> watchNextForDate(DateTime localDate);
  Future<AltarRitual> save(AltarRitualDraft draft);
  Future<void> setPaused(String ritualId, bool paused);
  Future<void> snooze(String ritualId, DateTime until);
  Future<void> archive(String ritualId);
}
```

Use one write transaction for item upsert, ritual upsert, and device state. `watchNextForDate` excludes archived/paused/disabled records and orders overdue first, then the earliest remaining local time. It returns only one ritual.

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
dart format lib/features/altar test/features/altar
flutter test test/features/altar/altar_ritual_repository_test.dart test/core/database/app_database_sync_test.dart
```

Expected: PASS.

```powershell
git add apps/soulbuddy/lib/features/altar apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/test/features/altar apps/soulbuddy/test/core/database/app_database_sync_test.dart
git commit -m "feat: add daily altar ritual persistence"
```

## Task 5: Build Voice Tablet capture and playback UI

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/providers/voice_tablet_providers.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_sheet.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/personal_prayer_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_detail_screen.dart`
- Test: `apps/soulbuddy/test/features/prayers/voice_tablet_flow_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover the exact copy and state transitions:

```dart
testWidgets('records a full prayer then offers an optional refrain', (tester) async {
  await pumpPersonalPrayerDetail(tester);
  await tester.tap(find.text('Record in my voice'));
  await tester.pumpAndSettle();

  expect(find.text('Record this prayer'), findsOneWidget);
  expect(find.textContaining('private'), findsOneWidget);

  await completeFakeRecording(tester, const Duration(minutes: 2));
  expect(find.text('Add a short refrain'), findsOneWidget);
  expect(find.text('Save Voice Tablet'), findsOneWidget);
});
```

Add cases for permission denial, record again, skip refrain, 25-second automatic stop, atomic failure/retry, library prayer source, and manual playback not recording a prayer session.

- [ ] **Step 2: Run and verify failure**

Run:

```powershell
flutter test test/features/prayers/voice_tablet_flow_test.dart
```

Expected: FAIL because UI/providers do not exist.

- [ ] **Step 3: Wire owner-scoped providers**

Expose repository, source-specific watcher, capture controller factory, asset finalization, and the existing single-active `MemoryAudioPlayer` through small Riverpod providers. Do not allow a widget to instantiate PowerSync, an audio store, or a recorder plugin directly.

- [ ] **Step 4: Implement the focused sheet**

The sheet state machine is:

```dart
enum VoiceTabletSheetStep { fullPrayer, fullReview, refrainChoice, refrain, save }
```

The exact prayer text remains visible above `AudioCapturePanel`. After full review, show two actions: `Add a short refrain` and `Save without a refrain`. Saving finalizes temporary bytes, calls the repository, deletes replaced keys after commit, and keeps reviewable temporary audio if metadata save fails.

- [ ] **Step 5: Implement manual player and detail entry points**

`VoiceTabletPlayer` shows title, waveform, duration, play/pause/seek, `I prayed`, `Keep on my Altar`, and an overflow menu for record again/archive. It uses the existing `recordPrayerSession` path with the exact personal revision or library prayer reference only when the user presses `I prayed`.

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
dart format lib/features/prayers test/features/prayers/voice_tablet_flow_test.dart
flutter test test/features/prayers/voice_tablet_flow_test.dart test/features/prayers/personal_prayer_practice_ui_test.dart test/features/prayers/prayer_library_flow_test.dart
```

Expected: PASS.

```powershell
git add apps/soulbuddy/lib/features/prayers apps/soulbuddy/test/features/prayers
git commit -m "feat: record and play private voice tablets"
```

## Task 6: Add daily Altar ritual setup and Today card

**Files:**
- Create: `apps/soulbuddy/lib/features/altar/providers/altar_ritual_providers.dart`
- Create: `apps/soulbuddy/lib/features/altar/presentation/altar_ritual_sheet.dart`
- Create: `apps/soulbuddy/lib/features/altar/presentation/today_altar_card.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart`
- Modify: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Modify: `apps/soulbuddy/lib/features/today/providers/daily_practice_providers.dart`
- Test: `apps/soulbuddy/test/features/altar/altar_ritual_ui_test.dart`
- Test: `apps/soulbuddy/test/features/today/today_prayer_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('adds a Voice Tablet as a daily altar ritual', (tester) async {
  await pumpVoiceTabletPlayer(tester);
  await tester.tap(find.text('Keep on my Altar'));
  await tester.pumpAndSettle();

  expect(find.text('Daily'), findsOneWidget);
  expect(find.text('Refrain'), findsOneWidget);
  expect(find.text('Save ritual'), findsOneWidget);

  await tester.tap(find.text('Save ritual'));
  await tester.pumpAndSettle();
  expect(fakeRepository.saved.schedule.type, AltarScheduleType.daily);
});
```

Add Today tests for one next/current ritual, compact empty state, due/listening/completed/missing-audio states, `Later`, pause/edit/remove, 200% text, and no new fourth Covenant Slab category.

- [ ] **Step 2: Run and verify failure**

Run:

```powershell
flutter test test/features/altar/altar_ritual_ui_test.dart test/features/today/today_prayer_test.dart
```

Expected: FAIL because the ritual UI does not exist.

- [ ] **Step 3: Implement compact ritual setup**

The first-slice sheet includes Daily/selected weekdays, local time, Refrain/Full prayer/Open quietly, enable-on-device, and Save. Do not show sound-bed or meditation-duration controls until their implementation plan lands. If no refrain exists, disable `Refrain` with `Record a short refrain first` and preselect `Full prayer`.

- [ ] **Step 4: Implement Today projection**

Place `TodayAltarCard` after the Covenant Slabs and before the selected prayer detail. Empty copy is exactly:

```text
At your Altar
Keep a prayer or memory before you.
```

The primary empty action is `Add to my Altar`. When due, the primary action is `Listen`; `I prayed` is separate and writes one exact prayer session. After confirmation, the card remains available for replay but changes its factual state to `Prayed today` without celebration, streak, or disabling access.

- [ ] **Step 5: Preserve daily practice semantics**

Update the daily projection so a non-retracted prayer session created from an Altar ritual satisfies `DailyPractice.pray`. Do not add `altar` to `DailyPractice`, alter the denominator, or mark completion on playback.

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
dart format lib/features/altar lib/features/today test/features/altar test/features/today
flutter test test/features/altar/altar_ritual_ui_test.dart test/features/today/today_prayer_test.dart test/features/today/daily_practice_state_test.dart test/core/presentation/covenant_slabs_test.dart
```

Expected: PASS.

```powershell
git add apps/soulbuddy/lib/features/altar apps/soulbuddy/lib/features/today apps/soulbuddy/lib/features/prayers/presentation/voice_tablet_player.dart apps/soulbuddy/test/features/altar apps/soulbuddy/test/features/today
git commit -m "feat: add voice tablets to the daily altar"
```

## Task 7: Add end-to-end device coverage and update contracts

**Files:**
- Create: `apps/soulbuddy/integration_test/voice_tablet_altar_flow_test.dart`
- Modify: `apps/soulbuddy/test/core/feedback/audio_asset_contract_test.dart`
- Modify: `README.md`
- Modify: `docs/architecture/local-first.md`

- [ ] **Step 1: Write the integration flow**

The test must:

```text
open a personal prayer
record and review a full Voice Tablet
record a <=25-second Prayer Refrain
save both locally
reopen and play the full recording
add it as a daily Altar ritual
see it on Today
tap Listen and verify no prayer session exists
tap I prayed and verify one exact-revision session exists
undo and verify the session is retracted
restart the app and replay the same local assets
```

Use fake recorder/audio assets in CI and retain a manual real-microphone physical-device run in the verification checklist.

- [ ] **Step 2: Run focused integration and regression tests**

Run:

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
flutter test integration_test/voice_tablet_altar_flow_test.dart -d chrome
flutter test
flutter analyze
flutter build web --release
flutter build apk --debug
```

Expected: all Flutter tests and analysis pass; web and Android builds complete.

- [ ] **Step 3: Run backend verification**

Run:

```powershell
Set-Location C:\dev\soulbuddy\services\api
php artisan test
vendor/bin/pint --test
composer validate --strict
composer audit --no-interaction
```

Expected: all Laravel tests pass, Pint is clean, Composer validation succeeds, and audit reports no known vulnerabilities.

- [ ] **Step 4: Verify on connected Android hardware**

Run:

```powershell
Set-Location C:\dev\soulbuddy\apps\soulbuddy
flutter devices
flutter run --debug
```

On the connected device, complete the integration sequence with the physical microphone; inspect Today at normal and 200% text; lock/unlock and background/foreground during recording; disconnect/reconnect Bluetooth during playback; confirm that playback alone never marks `I prayed`; and confirm that the daily Altar card fits without unnecessary scrolling.

- [ ] **Step 5: Update documentation**

Document that Voice Tablet audio remains on its creating device, daily ritual metadata syncs, playback does not count as prayer, ambient sounds are not yet in this slice, and custom notification audio still uses the ordinary cue until the third plan.

- [ ] **Step 6: Final verification and commit**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors and only intended documentation/test changes remain.

```powershell
git add apps/soulbuddy/integration_test/voice_tablet_altar_flow_test.dart apps/soulbuddy/test/core/feedback/audio_asset_contract_test.dart README.md docs/architecture/local-first.md
git commit -m "test: verify voice tablet altar journey"
```

## Completion criteria

- A saved personal or library prayer can become a private Voice Tablet.
- The full prayer and optional <=25-second Prayer Refrain can be recorded, reviewed, replaced, reopened, played, and deleted offline.
- A Voice Tablet can be kept on the Altar and assigned a daily or weekday local time.
- Today shows one compact current/next Altar ritual without adding a dashboard or fourth practice score.
- Playback never creates a prayer session; explicit `I prayed` creates exactly one session for the correct revision and supports Undo.
- Metadata sync is ownership-safe and replay-safe; audio bytes never leave the device.
- Existing prayer reminders, TTS, encounter audio, daily remembrance, and Covenant Slabs remain green.
- Android physical-device capture/playback and compact Today UX are verified before the slice is called complete.
