# Prayer Library and Practices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a fast, offline-first prayer library ordered by community votes, prayer detail, a daily selection, and one optional practical action without adding AI, metrics, or social performance.

**Architecture:** Approved library prayers use a local-only bundled fallback plus a PowerSync-backed canonical table; canonical rows take precedence by stable UUID when available. A small repository boundary owns the merged library query, the user's vote, and the dated Today selection; Flutter screens consume it through Riverpod. Laravel stores the canonical library, server-derived vote totals, and private selections, while the current mutation endpoint extends its allowlist with explicit per-table handlers.

**Tech Stack:** Flutter, Riverpod, GoRouter, PowerSync SQLite, Laravel, PostgreSQL-compatible migrations, Pest, Flutter widget/integration tests.

---

## Scope decisions

- This slice implements the approved roadmap workstream **Prayer library and practices**.
- It does not implement AI drafting, chat, notifications, streaks, public profiles, or personalized-generation requests.
- Library copy is editorial content, not invented Bible quotation and not presented as words from God.
- Voting affects ordering but is never shown as a spiritual score. The interface uses `Helpful` rather than competitive ranking language.
- `Use today` is a dated private selection. It does not imply the app chose a prayer on God's behalf.
- A library prayer can suggest one brief action. The user may include it for Today or omit it; completion has no animation or reward.

### Task 1: Add prayer library domain and local schema

**Files:**
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/library_prayer.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/today_prayer.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_repository.dart`
- Create: `apps/soulbuddy/test/features/prayers/prayer_repository_test.dart`
- Modify: `apps/soulbuddy/test/helpers/powersync_test_database.dart`

- [ ] **Step 1: Write failing repository tests**

Cover these contracts against a real temporary PowerSync database:

```dart
test('lists published prayers by helpful votes then title', () async {
  await seedPrayer(id: 'b', title: 'Peace', helpfulCount: 3);
  await seedPrayer(id: 'a', title: 'Morning', helpfulCount: 8);
  expect((await repository.watchLibrary().first).map((p) => p.id), ['a', 'b']);
});

test('filters by grounding and purpose', () async {
  final result = await repository
      .watchLibrary(grounding: PrayerGrounding.catholic, purpose: PrayerPurpose.family)
      .first;
  expect(result.map((p) => p.title), ['For my family']);
});

test('selects a prayer and optional action for today offline', () async {
  await repository.selectForToday('prayer-1', includeAction: true);
  final today = await repository.watchToday(DateTime(2026, 8, 11)).first;
  expect(today?.prayer.id, 'prayer-1');
  expect(today?.includeAction, isTrue);
});
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_repository_test.dart
```

Expected: compilation fails because prayer models and repository do not exist.

- [ ] **Step 3: Add focused domain models and repository contract**

Use enums with stable wire values:

```dart
enum PrayerGrounding { generalChristian, catholic }
enum PrayerPurpose { daily, gratitude, guidance, family, healing, work, forgiveness, difficultTime }

class LibraryPrayer {
  const LibraryPrayer({
    required this.id,
    required this.title,
    required this.body,
    required this.grounding,
    required this.purpose,
    required this.helpfulCount,
    required this.viewerMarkedHelpful,
    this.action,
  });
  // final fields only; no mutable UI state.
}

abstract interface class PrayerRepository {
  Stream<List<LibraryPrayer>> watchLibrary({
    PrayerGrounding? grounding,
    PrayerPurpose? purpose,
  });
  Stream<LibraryPrayer?> watchPrayer(String id);
  Future<void> setHelpful(String prayerId, {required bool value});
  Future<void> selectForToday(String prayerId, {required bool includeAction});
  Stream<TodayPrayer?> watchToday(DateTime localDate);
  Future<void> completeTodayAction(DateTime localDate, {required bool value});
}
```

- [ ] **Step 4: Add PowerSync tables and repository implementation**

Add these tables. `bundled_prayers` is local-only so importing app content can never enter the upload queue; `library_prayers` is populated only by PowerSync downloads:

```dart
Table('library_prayers', [
  Column.text('title'), Column.text('body'), Column.text('grounding'),
  Column.text('purpose'), Column.text('action'), Column.integer('helpful_count'),
  Column.text('published_at'), Column.text('archived_at'),
], indexes: [
  Index('library_prayers_order', [IndexedColumn('helpful_count'), IndexedColumn('title')]),
  Index('library_prayers_filter', [IndexedColumn('grounding'), IndexedColumn('purpose')]),
]),
Table.localOnly('bundled_prayers', [
  Column.text('title'), Column.text('body'), Column.text('grounding'),
  Column.text('purpose'), Column.text('action'), Column.integer('helpful_count'),
  Column.integer('content_version'), Column.text('archived_at'),
]),
Table('prayer_votes', [Column.text('owner_id'), Column.text('prayer_id'), Column.text('created_at')],
  indexes: [Index('prayer_votes_owner_prayer', [IndexedColumn('owner_id'), IndexedColumn('prayer_id')])]),
Table('today_prayers', [
  Column.text('owner_id'), Column.text('local_date'), Column.text('prayer_id'),
  Column.integer('include_action'), Column.integer('action_completed'), Column.text('created_at'),
], indexes: [Index('today_prayers_owner_date', [IndexedColumn('owner_id'), IndexedColumn('local_date')])]),
```

Use deterministic IDs for vote and Today rows: UUIDv5 over `ownerId:prayerId` and `ownerId:yyyy-MM-dd`. `watchLibrary` merges canonical and bundled rows with canonical precedence, left-joins the viewer's vote, and sorts `helpful_count DESC, title COLLATE NOCASE ASC`. Private writes happen locally first.

- [ ] **Step 5: Run focused tests and commit**

```powershell
flutter test test/features/prayers/prayer_repository_test.dart
git add apps/soulbuddy/lib/core/database apps/soulbuddy/lib/features/prayers apps/soulbuddy/test/features/prayers apps/soulbuddy/test/helpers
git commit -m "feat: add offline prayer library repository"
```

Expected: repository tests pass.

### Task 2: Bundle a restrained starter library

**Files:**
- Create: `apps/soulbuddy/assets/content/prayer_library.json`
- Create: `apps/soulbuddy/lib/features/prayers/data/bundled_prayer_importer.dart`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Create: `apps/soulbuddy/test/features/prayers/bundled_prayer_importer_test.dart`

- [ ] **Step 1: Write the failing import test**

Assert that importing twice is idempotent, archived records are not surfaced, and all starter records have non-empty title/body plus approved grounding and purpose values.

- [ ] **Step 2: Run the test and verify RED**

```powershell
flutter test test/features/prayers/bundled_prayer_importer_test.dart
```

Expected: missing importer and asset.

- [ ] **Step 3: Add eight editorial starter prayers**

The JSON shape is:

```json
{
  "version": 1,
  "prayers": [
    {
      "id": "0198a100-0000-7000-8000-000000000001",
      "title": "For this day",
      "body": "Father, keep me near you today. Give me wisdom for what is before me, patience with those I meet, and a willing heart to do what is good. Through Christ our Lord. Amen.",
      "grounding": "general_christian",
      "purpose": "daily",
      "action": "Do the next good thing without delay.",
      "helpful_count": 0
    }
  ]
}
```

Add seven more records covering gratitude, guidance, family, healing, work, forgiveness, and difficult times. Keep each prayer under 110 words, avoid invented quotations, avoid claims that God caused an event, and make Catholic entries recognizable through grounding and conclusion without requiring fixed devotional formats.

- [ ] **Step 4: Implement versioned idempotent import**

`BundledPrayerImporter.ensureLoaded()` reads the asset, validates every controlled value, then uses `INSERT ... ON CONFLICT(id) DO UPDATE` against `bundled_prayers` only. It must not touch canonical rows, private votes, or Today selections. Call it after `AppDatabase.open` and before the prayer repository is returned.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/features/prayers/bundled_prayer_importer_test.dart
git add apps/soulbuddy/assets apps/soulbuddy/lib/features/prayers/data apps/soulbuddy/pubspec.yaml apps/soulbuddy/test/features/prayers
git commit -m "content: add starter prayer library"
```

### Task 3: Build library and prayer detail screens

**Files:**
- Replace: `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_detail_screen.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_tile.dart`
- Create: `apps/soulbuddy/lib/features/prayers/providers/prayer_providers.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Create: `apps/soulbuddy/test/features/prayers/prayer_library_flow_test.dart`

- [ ] **Step 1: Write the failing widget flow**

Test this exact interaction with an in-memory repository:

```text
Prayers -> Choose from library -> filter General Christian + Family
-> open For my family -> see full prayer -> mark Helpful -> Use today
```

Assert 48dp controls, readable body text at 200% scale, and no streak/rank/leaderboard language.

- [ ] **Step 2: Run the test and verify RED**

```powershell
flutter test test/features/prayers/prayer_library_flow_test.dart
```

- [ ] **Step 3: Implement the library screen**

The top of Prayers contains only two primary actions:

```text
Choose from library
Create personalized · Later
```

Below, use horizontally scrollable filter chips for grounding and purpose. The list tile shows title, purpose, grounding, and `Helpful · N`; it does not show avatars, author prestige, or rank numbers. Empty filtered state: `No prayer matches these choices yet.` with `Clear filters`.

- [ ] **Step 4: Implement detail and routing**

Add `/prayers/:prayerId`. The detail screen shows title, grounding/purpose, prayer body, optional action, `Helpful`, and `Use today`. The action defaults included when present but can be unchecked in a small confirmation sheet before saving.

- [ ] **Step 5: Run tests and commit**

```powershell
flutter test test/features/prayers/prayer_library_flow_test.dart
git add apps/soulbuddy/lib/app apps/soulbuddy/lib/features/prayers apps/soulbuddy/test/features/prayers
git commit -m "feat: add prayer library and detail flow"
```

### Task 4: Put the selected prayer on Today

**Files:**
- Replace: `apps/soulbuddy/lib/features/today/presentation/today_screen.dart`
- Create: `apps/soulbuddy/test/features/today/today_prayer_test.dart`

- [ ] **Step 1: Write failing Today tests**

Assert:

- no selection shows `Choose a prayer for today`;
- a selection shows the prayer body and optional action;
- `Done` persists action completion without confetti, points, streaks, or public state;
- the date uses the device's local calendar day.

- [ ] **Step 2: Run the tests and verify RED**

```powershell
flutter test test/features/today/today_prayer_test.dart
```

- [ ] **Step 3: Implement Today as a quiet prayer surface**

Keep `Pray. Act. Remember.` as the heading. Render the selected prayer in one card, the optional action beneath it, and one link to choose a different prayer. Do not add statistics or a multi-card dashboard.

- [ ] **Step 4: Run tests and commit**

```powershell
flutter test test/features/today/today_prayer_test.dart
git add apps/soulbuddy/lib/features/today apps/soulbuddy/test/features/today
git commit -m "feat: add daily prayer and practice"
```

### Task 5: Add Laravel canonical library, votes, and selections

**Files:**
- Create: `services/api/database/migrations/2026_08_11_000000_create_prayer_library_tables.php`
- Create: `services/api/app/Models/LibraryPrayer.php`
- Create: `services/api/app/Models/PrayerVote.php`
- Create: `services/api/app/Models/TodayPrayer.php`
- Create: `services/api/database/seeders/PrayerLibrarySeeder.php`
- Modify: `services/api/database/seeders/DatabaseSeeder.php`
- Modify: `services/api/app/Domain/Encounters/ApplyEncounterMutation.php`
- Rename: `services/api/app/Domain/Encounters/ApplyEncounterMutation.php` to `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Modify: `services/api/app/Http/Controllers/Api/SyncMutationController.php`
- Create: `services/api/tests/Feature/Sync/PrayerMutationTest.php`

- [ ] **Step 1: Write failing mutation tests**

Cover:

- one vote per `(user_id, prayer_id)` and idempotent removal;
- clients cannot directly write `helpful_count`;
- a user cannot modify another user's vote or Today selection;
- Today selection must reference a published prayer;
- a rejected vote does not block a later valid mutation;
- no prayer body is present in exception/log context assertions.

- [ ] **Step 2: Run the test and verify RED**

```powershell
cd services/api
php artisan test --filter=PrayerMutationTest
```

- [ ] **Step 3: Add database and seed model**

Create `library_prayers`, `prayer_votes`, and `today_prayers`. Enforce unique indexes on `(user_id, prayer_id)` and `(user_id, local_date)`. `helpful_count` is derived from vote rows for API/admin reads; mutation input never accepts it. Seed the same stable prayer UUIDs as the Flutter asset.

- [ ] **Step 4: Generalize the mutation dispatcher**

Move the existing service to `App\Domain\Sync\ApplySyncMutation` and retain all Encounter behavior/tests. Dispatch new tables to focused private methods:

```php
return match ($operation['table']) {
    'encounters' => $this->applyEncounter($user, $operation),
    'encounter_revisions' => $this->applyRevision($user, $operation),
    'prayer_votes' => $this->applyPrayerVote($user, $operation),
    'today_prayers' => $this->applyTodayPrayer($user, $operation),
};
```

Vote PUT creates the user's row; DELETE removes only that user's row. Today PUT/PATCH upserts only the user's dated selection and validates booleans. Preserve operation fingerprint/idempotency semantics for every table.

- [ ] **Step 5: Run all Laravel tests and commit**

```powershell
vendor/bin/pint --dirty
php artisan test
git add services/api
git commit -m "feat: sync prayer votes and daily selections"
```

### Task 6: Verify the complete offline prayer slice

**Files:**
- Create: `apps/soulbuddy/integration_test/offline_prayer_flow_test.dart`
- Modify: `scripts/run_web_integration.ps1`
- Modify: `scripts/verify.ps1`
- Modify: `README.md`
- Modify: `docs/architecture/local-first.md`

- [ ] **Step 1: Add the real-browser flow**

Exercise:

```text
launch without sync -> Prayers -> filter -> detail -> Helpful -> Use today
-> Today -> complete action -> close/reopen local database -> Today still shows selection
```

The ChromeDriver script runs both integration files. The test must not require Laravel, PowerSync service, or network configuration.

- [ ] **Step 2: Document the runnable boundary**

README documents the bundled content import, local-only run, and verification commands. Architecture documents canonical server totals, private vote/selection ownership, offline optimistic writes, and the absence of gamification.

- [ ] **Step 3: Run fresh verification**

```powershell
scripts/verify.ps1
scripts/run_web_integration.ps1
cd apps/soulbuddy
flutter build apk --debug
cd ../..
git diff --check
git status --short
```

Expected: Flutter analysis passes; every Flutter/Laravel test passes; Flutter web and Android builds pass; both real Chrome flows pass; no generated database or build output is staged.

- [ ] **Step 4: Review and commit**

Run an independent code review focused on offline idempotency, ownership, private text logging, accessible interaction sizes, and the distinction between helpful ordering and spiritual scoring. Resolve Important findings, rerun verification, then commit:

```powershell
git add README.md apps docs scripts services
git commit -m "feat: deliver offline prayer library and practices"
```
