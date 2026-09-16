# Adaptive Daily Video Formation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a configurable, offline-capable 70-day daily video formation journey that begins after orientation, preserves history when preferences change, and advances only after explicit completion.

**Architecture:** Treat the reviewed workbook as an editorial source that generates a normalized versioned JSON catalog and an API database publication. Keep recommendation resolution deterministic in Dart so it works offline; sync user profiles, queues, recommendations, options, and immutable events through the existing PowerSync mutation path. Reuse SoulBuddy's Today, notification, Remember, Goal, and installation-identity patterns while preserving the separate orientation and Scripture progress stores.

**Tech Stack:** Python 3 + openpyxl for the editorial importer, Laravel 13/PHP 8.3 + Pest + MariaDB for catalog publication and synced records, Flutter/Dart + Riverpod + PowerSync + flutter_local_notifications + url_launcher for the mobile experience.

---

## File map

### Editorial pipeline

- Create `content/formation/SoulBuddy_Daily_Video_Progression_v3.xlsx` — normalized editable source workbook.
- Create `tools/formation/requirements.txt` — pinned workbook dependency.
- Create `tools/formation/import_daily_formation.py` — workbook normalization, validation, and deterministic JSON generation.
- Create `tools/formation/test_import_daily_formation.py` — importer regression tests.
- Create `services/api/resources/formation/daily_formation_v1.json` — generated API catalog snapshot.
- Create `apps/soulbuddy/assets/content/daily_formation_v1.json` — byte-identical generated offline snapshot.

### Laravel API

- Create `services/api/database/migrations/2026_09_16_000000_create_daily_formation_catalog_tables.php` — versioned videos, packs, days, rules.
- Create `services/api/database/migrations/2026_09_16_000001_create_daily_formation_progress_tables.php` — profiles, pack queues, recommendations, options, events.
- Create `services/api/app/Domain/Formation/FormationCatalog.php` — catalog validation and publication transaction.
- Create `services/api/app/Console/Commands/PublishFormationCatalog.php` — protected operator publication command.
- Create `services/api/app/Http/Controllers/Api/FormationCatalogController.php` — public published-catalog endpoint with checksum/ETag.
- Create `services/api/app/Domain/Sync/ApplyDailyFormationMutation.php` — owner-scoped progress mutations and immutable events.
- Create `services/api/docs/powersync-daily-formation-sync-rules.yaml` — deployable owner-scoped bucket definitions.
- Modify `services/api/app/Domain/Sync/ApplySyncMutation.php` — route formation tables to their validator/writer.
- Modify `services/api/routes/api.php` — expose read-only catalog endpoint.
- Create `services/api/tests/Feature/Formation/FormationCatalogTest.php` — publication and endpoint tests.
- Create `services/api/tests/Feature/Sync/DailyFormationMutationTest.php` — ownership, immutability, and idempotency tests.

### Flutter domain and data

- Create `apps/soulbuddy/lib/features/daily_formation/domain/formation_catalog.dart` — immutable video, pack, day, and catalog types.
- Create `apps/soulbuddy/lib/features/daily_formation/domain/formation_profile.dart` — configuration and priority types.
- Create `apps/soulbuddy/lib/features/daily_formation/domain/formation_recommendation.dart` — recommendation, option, event, and status types.
- Create `apps/soulbuddy/lib/features/daily_formation/application/formation_rules_engine.dart` — deterministic queue and daily option resolution.
- Create `apps/soulbuddy/lib/features/daily_formation/application/formation_today_state.dart` — orientation/setup/recommendation/completion precedence.
- Create `apps/soulbuddy/lib/features/daily_formation/data/formation_catalog_repository.dart` — API/cache/bundle catalog precedence.
- Create `apps/soulbuddy/lib/features/daily_formation/data/daily_formation_repository.dart` — repository contract.
- Create `apps/soulbuddy/lib/features/daily_formation/data/powersync_daily_formation_repository.dart` — local-first profile/progress persistence.
- Create `apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart` — repositories and current state.
- Modify `apps/soulbuddy/lib/core/database/app_schema.dart` — add PowerSync progress tables and local device delivery state.
- Modify `apps/soulbuddy/pubspec.yaml` — bundle generated catalog snapshot.

### Flutter experience

- Create `apps/soulbuddy/lib/features/daily_formation/presentation/formation_setup_screen.dart` — priorities, time budget, presentation, source, and reminders.
- Create `apps/soulbuddy/lib/features/daily_formation/presentation/daily_formation_card.dart` — compact Today recommendation.
- Create `apps/soulbuddy/lib/features/daily_formation/presentation/formation_choices_sheet.dart` — two optional alternatives.
- Create `apps/soulbuddy/lib/features/daily_formation/presentation/formation_checkin_sheet.dart` — Finished, Watched some, Not yet, Skip.
- Create `apps/soulbuddy/lib/features/daily_formation/presentation/formation_completion_screen.dart` — optional reflection and practical action.
- Create `apps/soulbuddy/lib/features/daily_formation/application/daily_formation_reminder_coordinator.dart` — daily alarm and completion check-in reconciliation.
- Modify `apps/soulbuddy/lib/features/prayers/domain/prayer_reminder.dart` — add daily-formation notification kind/actions.
- Modify `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart` — generic lock-screen copy and check-in actions.
- Modify `apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart` — orientation/setup/video state handoff.
- Modify `apps/soulbuddy/lib/app/router.dart` — setup, recommendation, and completion routes.
- Modify `apps/soulbuddy/lib/app/app.dart` — start coordinator and route notification responses.

### Flutter tests

- Create `apps/soulbuddy/test/features/daily_formation/formation_catalog_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/formation_catalog_repository_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/formation_rules_engine_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/powersync_daily_formation_repository_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/formation_setup_screen_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/daily_formation_card_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/formation_checkin_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/daily_formation_reminder_coordinator_test.dart`.
- Create `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart` — reviewed catalog/profile/recommendation builders shared by focused tests.
- Modify `apps/soulbuddy/test/features/formation/formation_today_card_test.dart` — assert orientation-to-setup-to-video precedence.

---

### Task 1: Normalize the workbook and generate the catalog

**Files:**
- Create: `content/formation/SoulBuddy_Daily_Video_Progression_v3.xlsx`
- Create: `tools/formation/requirements.txt`
- Create: `tools/formation/import_daily_formation.py`
- Create: `tools/formation/test_import_daily_formation.py`
- Create: `services/api/resources/formation/daily_formation_v1.json`
- Create: `apps/soulbuddy/assets/content/daily_formation_v1.json`

- [ ] **Step 1: Copy the supplied workbook into the repository**

Run:

```powershell
New-Item -ItemType Directory -Force content\formation | Out-Null
Copy-Item -LiteralPath 'C:\Users\Son\Downloads\SoulBuddy_Daily_Video_Progression_v3.xlsx' -Destination 'content\formation\SoulBuddy_Daily_Video_Progression_v3.xlsx'
```

Expected: the repository copy exists and the original file remains untouched.

- [ ] **Step 2: Pin the importer dependency**

```text
openpyxl==3.1.5
```

Run: `python -m pip install -r tools/formation/requirements.txt`

Expected: `Successfully installed openpyxl-3.1.5` or an already-satisfied result.

- [ ] **Step 3: Write failing importer tests**

Create tests that call `build_catalog(workbook_path)` and assert stable production requirements:

```python
import json
import re
import tempfile
import unittest
from pathlib import Path

from import_daily_formation import build_catalog, write_outputs

ROOT = Path(__file__).resolve().parents[2]
BOOK = ROOT / "content/formation/SoulBuddy_Daily_Video_Progression_v3.xlsx"


class FormationImportTest(unittest.TestCase):
    def test_builds_complete_clean_catalog(self):
        catalog = build_catalog(BOOK)
        self.assertEqual(1, catalog["version"])
        self.assertEqual(44, len(catalog["videos"]))
        self.assertEqual(10, len(catalog["packs"]))
        self.assertEqual(70, len(catalog["days"]))
        self.assertEqual("A Plentiful Harvest", catalog["packs"][0]["title"])
        encoded = json.dumps(catalog, ensure_ascii=False)
        self.assertNotIn("\ufffd", encoded)
        self.assertNotIn("must bear fruit", encoded.casefold())
        self.assertIsNone(re.search(r"garden.{0,24}empty", encoded.casefold()))
        self.assertTrue(all(v["runtimeSeconds"] <= 599 for v in catalog["videos"]))
        self.assertTrue(all(len(set(d["videoIds"])) == 3 for d in catalog["days"]))

    def test_writes_identical_api_and_mobile_snapshots(self):
        with tempfile.TemporaryDirectory() as directory:
            left = Path(directory) / "api.json"
            right = Path(directory) / "app.json"
            write_outputs(build_catalog(BOOK), [left, right])
            self.assertEqual(left.read_bytes(), right.read_bytes())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 4: Run tests and verify the red state**

Run: `python -m unittest tools/formation/test_import_daily_formation.py -v`

Expected: FAIL because `import_daily_formation` does not exist.

- [ ] **Step 5: Write the deterministic importer**

The module must expose these concrete entry points:

The module exports `normalize_workbook(Path)`, `build_catalog(Path)`,
`validate_catalog(dict)`, and `write_outputs(dict, list[Path])`. The CLI calls
them in that order and exits nonzero on any validation failure.

Use `VIDEO CATALOG` rows as the media source and resolve all `70-DAY MVP PATH` title/runtime/URL fields from video IDs instead of evaluating Excel formulas. Normalize pack `P01` to `A Plentiful Harvest`, convert `U+FFFD` by context, replace the blocked `must bear fruit` fragment and the legacy empty-garden warning, and fail if either remains. Generate sorted compact JSON with a trailing newline and this top-level shape:

```json
{
  "version": 1,
  "sourceSha256": "0000000000000000000000000000000000000000000000000000000000000000",
  "videos": [],
  "packs": [],
  "days": [],
  "rules": []
}
```

Validate exact URLs produced as `https://www.youtube.com/watch?v={youtube_id}`, 1–599 second runtime, `PRODUCTION_READY`, 44/10/70 counts, unique IDs, three distinct daily choices, valid foreign keys, required reflection/action fields, and clean Unicode.

- [ ] **Step 6: Generate and recalculate the repository workbook**

Run:

```powershell
python tools\formation\import_daily_formation.py `
  content\formation\SoulBuddy_Daily_Video_Progression_v3.xlsx `
  services\api\resources\formation\daily_formation_v1.json `
  apps\soulbuddy\assets\content\daily_formation_v1.json
python "$env:USERPROFILE\.agents\skills\xlsx\scripts\recalc.py" content\formation\SoulBuddy_Daily_Video_Progression_v3.xlsx 60
```

Expected: importer reports `44 videos, 10 packs, 70 days`; recalculation reports `status: success` and `total_errors: 0`.

- [ ] **Step 7: Run importer tests**

Run: `python -m unittest tools/formation/test_import_daily_formation.py -v`

Expected: PASS.

- [ ] **Step 8: Commit the editorial pipeline**

```powershell
git add content/formation tools/formation services/api/resources/formation apps/soulbuddy/assets/content/daily_formation_v1.json
git commit -m "feat: import daily formation catalog"
```

---

### Task 2: Persist and publish versioned catalog records

**Files:**
- Create: `services/api/database/migrations/2026_09_16_000000_create_daily_formation_catalog_tables.php`
- Create: `services/api/app/Domain/Formation/FormationCatalog.php`
- Create: `services/api/app/Console/Commands/PublishFormationCatalog.php`
- Create: `services/api/tests/Feature/Formation/FormationCatalogTest.php`

- [ ] **Step 1: Write failing publication tests**

```php
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

it('publishes one internally consistent catalog transaction', function () {
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();

    expect(DB::table('formation_catalog_versions')->where('published', true)->count())->toBe(1)
        ->and(DB::table('formation_videos')->count())->toBe(44)
        ->and(DB::table('formation_packs')->count())->toBe(10)
        ->and(DB::table('formation_days')->count())->toBe(70)
        ->and(DB::table('formation_rules')->count())->toBe(10);
});

it('keeps the prior publication active when validation fails', function () {
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();
    $published = DB::table('formation_catalog_versions')->where('published', true)->value('checksum');

    $bad = tempnam(sys_get_temp_dir(), 'formation-');
    file_put_contents($bad, '{"version":2,"videos":[]}');
    $this->artisan('formation:publish', ['file' => $bad])->assertFailed();

    expect(DB::table('formation_catalog_versions')->where('published', true)->value('checksum'))
        ->toBe($published);
});
```

- [ ] **Step 2: Verify publication tests fail**

Run: `php artisan test tests/Feature/Formation/FormationCatalogTest.php`

Expected: FAIL because the command and tables do not exist.

- [ ] **Step 3: Create catalog tables**

The migration creates:

```php
Schema::create('formation_catalog_versions', function (Blueprint $table) {
    $table->id();
    $table->unsignedInteger('version')->unique();
    $table->char('checksum', 64)->unique();
    $table->boolean('published')->default(false)->index();
    $table->timestamp('published_at')->nullable();
    $table->timestamps();
});
```

Add `formation_videos`, `formation_packs`, `formation_days`, and `formation_rules` with `catalog_version_id` foreign keys using `cascadeOnDelete()`. Use stable string IDs (`V001`, `P01`, `D001`, `R01`), JSON columns for tags/alternatives/eligibility, integer runtime and ordering columns, and text columns for objectives/reflections/actions. Add unique indexes on `(catalog_version_id, stable_id)` and `(catalog_version_id, canonical_day)`.

- [ ] **Step 4: Write the publication transaction**

`FormationCatalog::publish(string $path)` must decode with `JSON_THROW_ON_ERROR`, validate the same invariants as the Python importer, insert the version plus child records inside `DB::transaction`, set all prior versions to `published = false`, and publish the new version only after every child insert succeeds.

The command signature is:

```php
protected $signature = 'formation:publish {file : Validated formation catalog JSON}';
```

Return failure with a specific validation message and no database mutation.

- [ ] **Step 5: Run publication tests and the full migration suite**

Run:

```powershell
php artisan test tests/Feature/Formation/FormationCatalogTest.php
php artisan test tests/Unit/MariaDbMigrationCompatibilityTest.php
```

Expected: PASS.

- [ ] **Step 6: Commit catalog publication**

```powershell
git add services/api/database/migrations/2026_09_16_000000_create_daily_formation_catalog_tables.php services/api/app/Domain/Formation services/api/app/Console/Commands/PublishFormationCatalog.php services/api/tests/Feature/Formation
git commit -m "feat: publish versioned formation catalogs"
```

---

### Task 3: Serve the published catalog with offline-friendly caching

**Files:**
- Create: `services/api/app/Http/Controllers/Api/FormationCatalogController.php`
- Modify: `services/api/routes/api.php`
- Modify: `services/api/tests/Feature/Formation/FormationCatalogTest.php`

- [ ] **Step 1: Add failing endpoint tests**

```php
it('serves only the published catalog with a stable etag', function () {
    $this->artisan('formation:publish', [
        'file' => resource_path('formation/daily_formation_v1.json'),
    ])->assertSuccessful();

    $response = $this->getJson('/api/formation/catalog')->assertOk()
        ->assertJsonPath('data.version', 1)
        ->assertJsonCount(44, 'data.videos')
        ->assertJsonCount(70, 'data.days');

    $etag = $response->headers->get('ETag');
    expect($etag)->not->toBeNull();
    $this->withHeader('If-None-Match', $etag)
        ->get('/api/formation/catalog')
        ->assertStatus(304);
});

it('has no public catalog mutation endpoint', function () {
    $this->postJson('/api/formation/catalog', [])->assertStatus(405);
});
```

- [ ] **Step 2: Verify endpoint tests fail**

Run: `php artisan test tests/Feature/Formation/FormationCatalogTest.php`

Expected: FAIL with route not found.

- [ ] **Step 3: Add the read-only endpoint**

Register:

```php
Route::get('/formation/catalog', FormationCatalogController::class)
    ->middleware('throttle:120,1');
```

The controller loads the single published version and its ordered children, serializes the same keys as the generated snapshot, returns `Cache-Control: public, max-age=300, stale-if-error=86400`, sets `ETag` to the quoted checksum, and returns `304` when `If-None-Match` matches.

- [ ] **Step 4: Run endpoint tests**

Run: `php artisan test tests/Feature/Formation/FormationCatalogTest.php`

Expected: PASS.

- [ ] **Step 5: Commit the endpoint**

```powershell
git add services/api/routes/api.php services/api/app/Http/Controllers/Api/FormationCatalogController.php services/api/tests/Feature/Formation/FormationCatalogTest.php
git commit -m "feat: serve published formation catalog"
```

---

### Task 4: Add server-synced formation profiles and event history

**Files:**
- Create: `services/api/database/migrations/2026_09_16_000001_create_daily_formation_progress_tables.php`
- Create: `services/api/app/Models/FormationProfile.php`
- Create: `services/api/app/Models/FormationPackQueueItem.php`
- Create: `services/api/app/Models/FormationRecommendation.php`
- Create: `services/api/app/Models/FormationRecommendationOption.php`
- Create: `services/api/app/Models/FormationEvent.php`
- Create: `services/api/app/Domain/Sync/ApplyDailyFormationMutation.php`
- Create: `services/api/docs/powersync-daily-formation-sync-rules.yaml`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Create: `services/api/tests/Feature/Sync/DailyFormationMutationTest.php`

- [ ] **Step 1: Write failing sync tests**

Cover these exact behaviors:

```php
it('accepts an owned profile and immutable formation event', function () {
    [$user, $headers] = installationSyncIdentity();
    $profileId = (string) Str::uuid();
    $eventId = (string) Str::uuid();

    syncBatch($this, $headers, [
        put('formation_profiles', $profileId, formationProfileData($user)),
        put('formation_events', $eventId, formationEventData($user, 'video_completed')),
    ])->assertOk();

    expect(FormationProfile::find($profileId))->not->toBeNull()
        ->and(FormationEvent::find($eventId))->not->toBeNull();
});

it('rejects event patch delete and another owners records', function () {
    [$user, $headers] = installationSyncIdentity();
    syncBatch($this, $headers, [
        patch('formation_events', (string) Str::uuid(), ['event_type' => 'video_completed']),
    ])->assertUnprocessable()->assertJsonPath('error', 'immutable_formation_event');

    syncBatch($this, $headers, [
        put('formation_profiles', (string) Str::uuid(), formationProfileData($user, owner: (string) Str::uuid())),
    ])->assertForbidden();
});
```

Also test duplicate idempotency keys, invalid status transitions, a second `day_advanced` event for the same recommendation, option ownership, and deleting a profile without deleting history.

Define the test-local helpers at the bottom of
`DailyFormationMutationTest.php`: `installationSyncIdentity()` creates an
installation-authenticated user and headers; `syncBatch()` posts the standard
`operations` payload; `put()` and `patch()` build the existing mutation wire
shape; `formationProfileData()` and `formationEventData()` return complete valid
payloads and accept only the overrides used by each test.

- [ ] **Step 2: Verify sync tests fail**

Run: `php artisan test tests/Feature/Sync/DailyFormationMutationTest.php`

Expected: FAIL with unsupported table.

- [ ] **Step 3: Create progress tables and models**

Use UUID primary keys and owner foreign keys. Required database constraints:

```php
$table->unique(['owner_id']); // formation_profiles
$table->unique(['owner_id', 'queue_position']); // formation_pack_queue
$table->unique(['owner_id', 'local_date']); // formation_recommendations
$table->unique(['recommendation_id', 'position']); // options
$table->unique(['owner_id', 'idempotency_key']); // events
```

Profiles store JSON priorities plus timezone, `HH:MM` alarm, alarm/check-in flags, presentation/source preference, time budget `120..599`, optional explicit struggle, configuration version, timestamps. Recommendations store catalog/day/rule IDs, captured focus/title/runtime/URL snapshots, status, selected video, click/check-in/completion timestamps, and configuration version.

- [ ] **Step 4: Add mutation validation and writing**

`ApplyDailyFormationMutation::TABLES` is:

```php
private const TABLES = [
    'formation_profiles',
    'formation_pack_queue',
    'formation_recommendations',
    'formation_recommendation_options',
    'formation_events',
];
```

Reject event patch/delete, owner mismatch, unknown enum values, malformed local dates/timestamps, foreign keys outside the same owner, completed-to-clicked regression, and more than one advance per recommendation. Accept replay of the same event ID and idempotency key only when the stored semantic payload matches.

Wire `ApplySyncMutation` to validate and apply these operations within its existing batch transaction before a successful sync response.

Create owner-scoped PowerSync buckets for each synced formation table. Profile,
queue, recommendation, and event queries filter `owner_id = bucket.owner_id`.
Recommendation-option rows join through `formation_recommendations` and use
that recommendation's owner. The bucket parameter query reads the authenticated
owner claim already issued by `PowerSyncTokenController`; no sensitive-struggle
field appears in a public or global bucket.

- [ ] **Step 5: Run sync and migration tests**

Run:

```powershell
php artisan test tests/Feature/Sync/DailyFormationMutationTest.php
php artisan test tests/Feature/Sync
php artisan test tests/Unit/MariaDbMigrationCompatibilityTest.php
```

Expected: PASS.

- [ ] **Step 6: Commit synced progress storage**

```powershell
git add services/api/database/migrations/2026_09_16_000001_create_daily_formation_progress_tables.php services/api/app/Models/Formation*.php services/api/app/Domain/Sync/ApplyDailyFormationMutation.php services/api/app/Domain/Sync/ApplySyncMutation.php services/api/docs/powersync-daily-formation-sync-rules.yaml services/api/tests/Feature/Sync/DailyFormationMutationTest.php
git commit -m "feat: sync daily formation progress"
```

---

### Task 5: Parse, cache, and fall back to the bundled catalog

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/domain/formation_catalog.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/data/formation_catalog_repository.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_catalog_test.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_catalog_repository_test.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart`
- Modify: `apps/soulbuddy/pubspec.yaml`

- [ ] **Step 1: Write failing domain validation tests**

```dart
test('parses the reviewed v1 catalog', () {
  final catalog = FormationCatalog.fromJson(reviewedCatalogJson());
  expect(catalog.version, 1);
  expect(catalog.videos, hasLength(44));
  expect(catalog.packs, hasLength(10));
  expect(catalog.days, hasLength(70));
});

test('rejects an overlong or dangling video option', () {
  final json = reviewedCatalogJson();
  (json['videos'] as List).first['runtimeSeconds'] = 600;
  expect(() => FormationCatalog.fromJson(json), throwsFormatException);
});
```

- [ ] **Step 2: Verify domain tests fail**

Run: `flutter test test/features/daily_formation/formation_catalog_test.dart`

Expected: FAIL because `FormationCatalog` does not exist.

- [ ] **Step 3: Add immutable catalog types and validation**

Define `FormationVideo`, `FormationPack`, `FormationDay`, `FormationRule`, and `FormationCatalog`. Store maps by stable ID after parsing so resolution does not scan lists. `FormationCatalog.fromJson` enforces counts, uniqueness, ordering, runtime, URL, foreign keys, clean text, and exactly three distinct video IDs per day.

- [ ] **Step 4: Write failing repository precedence tests**

```dart
test('uses API then cache then bundle without accepting corrupt data', () async {
  final writes = <String>[];
  final repository = FormationCatalogRepository(
    apiBaseUri: Uri.parse('https://example.test'),
    client: MockClient((_) async => http.Response(validCatalogBody(version: 2), 200)),
    loadBundle: () async => validCatalogBody(version: 1),
    readCache: () async => null,
    writeCache: (value) async => writes.add(value),
  );
  expect((await repository.load()).version, 2);
  expect(writes, hasLength(1));
});
```

Add tests for HTTP failure, timeout, invalid checksum/version, corrupt cache, newer cached version, and bounded response size.

`formation_test_fixtures.dart` loads the checked-in v1 JSON with
`File('assets/content/daily_formation_v1.json').readAsStringSync()`, exposes
`reviewedCatalogJson()`, and exposes `validCatalogBody({required int version})`
by deep-copying the parsed fixture, replacing `version`, and assigning a valid
64-character lowercase source SHA fixture.

- [ ] **Step 5: Implement repository precedence**

Request `/api/formation/catalog` with `If-None-Match` when a cache manifest exists. Accept only a fully validated catalog with matching checksum. Cache `{etag, catalog}` in secure storage. On failure, use the newest valid cache or bundle; never replace a valid cache with invalid data.

- [ ] **Step 6: Bundle the snapshot and run tests**

Add:

```yaml
assets:
  - assets/content/daily_formation_v1.json
```

Run:

```powershell
flutter test test/features/daily_formation/formation_catalog_test.dart test/features/daily_formation/formation_catalog_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit catalog access**

```powershell
git add apps/soulbuddy/lib/features/daily_formation apps/soulbuddy/test/features/daily_formation apps/soulbuddy/pubspec.yaml
git commit -m "feat: load offline daily formation catalog"
```

---

### Task 6: Resolve adaptive pack queues and daily recommendations

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/domain/formation_profile.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/domain/formation_recommendation.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/application/formation_rules_engine.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_rules_engine_test.dart`
- Modify: `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart`

- [ ] **Step 1: Write failing queue tests**

```dart
test('keeps foundation first and promotes explicit priorities', () {
  final engine = FormationRulesEngine();
  final catalog = reviewedCatalog();
  final queue = engine.packQueue(
    catalog: catalog,
    profile: profile(priorities: [FormationPriority.discipline, FormationPriority.prayer]),
    completedPackIds: const {},
  );
  expect(queue.first, 'P01');
  expect(queue.indexOf('P05'), lessThan(queue.indexOf('P02')));
  expect(queue.indexOf('P08'), lessThan(queue.indexOf('P02')));
  expect(queue.toSet(), hasLength(10));
});

test('configuration changes preserve completed and active packs', () {
  final engine = FormationRulesEngine();
  final catalog = reviewedCatalog();
  final queue = engine.reconfigure(
    catalog: catalog,
    previous: ['P01', 'P05', 'P08', 'P02'],
    completedPackIds: {'P01'},
    activePackId: 'P05',
    profile: profile(priorities: [FormationPriority.forgiveness]),
  );
  expect(queue.take(2), ['P01', 'P05']);
  expect(queue[2], 'P07');
});
```

- [ ] **Step 2: Write failing recommendation tests**

Cover rule priority, one/three choice preference, first pack day, explicit struggle opt-in, strict time budget, prior-14-day avoidance, repeated incompletion, unresolved recommendation preservation, unique choices, unavailable video replacement, and day-70 maintenance.

Extend `formation_test_fixtures.dart` with `reviewedCatalog()` and
`profile({List<FormationPriority> priorities = const []})`; every test creates
its engine and inputs explicitly.

- [ ] **Step 3: Verify rules tests fail**

Run: `flutter test test/features/daily_formation/formation_rules_engine_test.dart`

Expected: FAIL because domain types and engine do not exist.

- [ ] **Step 4: Add validated configuration types**

Use enums with explicit wire values:

```dart
enum FormationPresentation { automatic, single, choices }
enum FormationSourcePreference { any, broadChristian, catholicInclusive }
enum FormationPriority { freedom, prayer, discipline, humility, forgiveness, generosity, virtue, service, balanced }
enum FormationRecommendationStatus { suggested, clicked, partial, completed, skipped, expired }
```

`FormationProfile` validates timezone, `PrayerLocalTime`, a 120–599 second budget, unique priorities, optional allowed struggle, and a positive configuration version.

`formation_recommendation.dart` also defines `FormationEvent`,
`FormationProgressSnapshot`, `FormationMaintenanceMode`, and
`FormationMaintenanceChoice`; the rules signatures below use those exact
types.

- [ ] **Step 5: Implement deterministic resolution**

Expose:

```dart
List<String> packQueue({
  required FormationCatalog catalog,
  required FormationProfile profile,
  required Set<String> completedPackIds,
});
List<String> reconfigure({
  required FormationCatalog catalog,
  required List<String> previous,
  required Set<String> completedPackIds,
  required String? activePackId,
  required FormationProfile profile,
});
FormationRecommendation resolve({
  required FormationCatalog catalog,
  required FormationProfile profile,
  required FormationProgressSnapshot progress,
  required DateTime localDate,
});
FormationMaintenanceChoice maintenance({
  required FormationCatalog catalog,
  required List<FormationEvent> history,
});
```

Sort ties by workbook option position then stable video ID. Capture rule ID and video title/runtime/URL snapshots in every recommendation. Return the existing unresolved recommendation before evaluating other rules.

- [ ] **Step 6: Run rules tests**

Run: `flutter test test/features/daily_formation/formation_rules_engine_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the rules engine**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/domain apps/soulbuddy/lib/features/daily_formation/application/formation_rules_engine.dart apps/soulbuddy/test/features/daily_formation/formation_rules_engine_test.dart
git commit -m "feat: resolve adaptive formation paths"
```

---

### Task 7: Persist local-first profiles, queues, recommendations, and events

**Files:**
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/data/daily_formation_repository.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/data/powersync_daily_formation_repository.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/powersync_daily_formation_repository_test.dart`
- Modify: `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart`

- [ ] **Step 1: Write failing repository tests**

Use `helpers/powersync_test_database.dart` and verify:

```dart
test('finished advances once and preserves an immutable completion event', () async {
  final recommendation = await repository.resolveToday(localDate: '2026-09-16');
  await repository.finish(recommendation.id, videoId: recommendation.selectedVideoId!);
  await repository.finish(recommendation.id, videoId: recommendation.selectedVideoId!);

  final state = await repository.watchState().first;
  expect(state.currentDay, 2);
  expect(await eventCount('video_completed'), 1);
  expect(await eventCount('day_advanced'), 1);
});

test('reconfigure changes only future queue entries', () async {
  await repository.completePack('P01');
  await repository.activatePack('P05');
  await repository.saveProfile(profile(priorities: [FormationPriority.forgiveness]));
  expect(await queueIds(), startsWith(['P01', 'P05', 'P07']));
});
```

Also test click/no advance, partial, skip, replace, offline replay, same-date deduplication, history snapshots, and independent Scripture progress.

The repository test file defines `eventCount`, `queueIds`, and database seed
helpers against its local test database. Add `profile()` to the shared fixture
file before using it in these tests.

- [ ] **Step 2: Verify repository tests fail**

Run: `flutter test test/features/daily_formation/powersync_daily_formation_repository_test.dart`

Expected: FAIL because tables and repository do not exist.

- [ ] **Step 3: Add PowerSync tables**

Add synced tables matching the server columns: `formation_profiles`, `formation_pack_queue`, `formation_recommendations`, `formation_recommendation_options`, `formation_events`. Add local-only `formation_device_deliveries` with reminder/check-in notification IDs, next alarm, pending check-in, permission state, timezone, and updated time.

Indexes must support owner/current-date recommendation, owner/status events, queue position, recommendation options, and due device deliveries.

- [ ] **Step 4: Implement transactional repository methods**

The interface exposes:

```dart
Stream<DailyFormationState> watchState();
Future<void> saveProfile(FormationProfile profile);
Future<FormationRecommendation> resolveToday({required DateTime localDate});
Future<void> selectOption(String recommendationId, String videoId);
Future<void> recordClick(String recommendationId, String videoId, DateTime at);
Future<void> finish(String recommendationId, {required String videoId});
Future<void> markPartial(String recommendationId, {required String videoId});
Future<void> skip(String recommendationId, {required String videoId});
Future<FormationRecommendation> replace(String recommendationId);
```

Use UUIDv5 IDs derived from owner/local date for recommendations and owner/recommendation/event semantic keys for events. `finish` inserts completion and advance events and updates the recommendation in one `writeTransaction`; existing idempotency keys return without mutation.

- [ ] **Step 5: Run repository and schema tests**

Run:

```powershell
flutter test test/features/daily_formation/powersync_daily_formation_repository_test.dart
flutter test test/core/database
```

Expected: PASS.

- [ ] **Step 6: Commit persistence**

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/daily_formation/data apps/soulbuddy/test/features/daily_formation/powersync_daily_formation_repository_test.dart
git commit -m "feat: persist daily formation history"
```

---

### Task 8: Add providers and configurable formation setup

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_setup_screen.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_setup_screen_test.dart`
- Modify: `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`

- [ ] **Step 1: Write failing setup tests**

```dart
testWidgets('saves an adaptive profile without enabling reminders implicitly', (tester) async {
  final saved = <FormationProfile>[];
  await tester.pumpWidget(testApp(onSave: saved.add));
  await tester.tap(find.text('Discipline and consistency'));
  await tester.tap(find.text('Prayer and the Holy Spirit'));
  await tester.tap(find.text('About 5 minutes'));
  await tester.tap(find.text('Choose for me'));
  await tester.tap(find.text('Begin daily formation'));
  await tester.pumpAndSettle();

  expect(saved.single.priorities, [FormationPriority.discipline, FormationPriority.prayer]);
  expect(saved.single.timeBudgetSeconds, 300);
  expect(saved.single.alarmEnabled, isFalse);
});
```

Add large-text, sensitive opt-in, reminder permission denial, existing-profile editing, and future-queue-only reconfiguration tests.

The test file defines `testApp({required ValueChanged<FormationProfile>
onSave})` with repository/provider overrides and a `MaterialApp`; it does not
depend on production storage.

- [ ] **Step 2: Verify setup tests fail**

Run: `flutter test test/features/daily_formation/formation_setup_screen_test.dart`

Expected: FAIL because the setup screen does not exist.

- [ ] **Step 3: Add providers**

Provide catalog, repository, profile, current state, and current recommendation through Riverpod. Repository providers depend on `appDatabaseProvider`, `localIdentityProvider`, catalog repository, and the rules engine. Dispose streams and HTTP clients with `ref.onDispose`.

- [ ] **Step 4: Build the setup experience**

Use compact `SacredSurface` sections for:

- priority chips in chosen order;
- time choices 2, 3, 5, 7, or 9 minutes;
- Choose for me, One video, or Three choices;
- source preference;
- optional sensitive track behind an explicit disclosure;
- reminder time and separate completion check-in switch.

Primary copy: **Shape my daily formation**. Purpose copy: **Grow through one focused lesson and one faithful action each day.** Primary action: **Begin daily formation** or **Save changes**. Do not use UI narration.

- [ ] **Step 5: Add routes and run tests**

Register `/formation/setup` and `/formation/settings`. Run:

```powershell
flutter test test/features/daily_formation/formation_setup_screen_test.dart
flutter test test/app/app_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit setup**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/providers apps/soulbuddy/lib/features/daily_formation/presentation/formation_setup_screen.dart apps/soulbuddy/lib/app/router.dart apps/soulbuddy/test/features/daily_formation/formation_setup_screen_test.dart
git commit -m "feat: configure daily formation path"
```

---

### Task 9: Replace post-orientation Today progression with the daily video card

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/presentation/daily_formation_card.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_choices_sheet.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/application/formation_today_state.dart`
- Modify: `apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/daily_formation_card_test.dart`
- Modify: `apps/soulbuddy/test/features/formation/formation_today_card_test.dart`

- [ ] **Step 1: Write failing Today-state tests**

Cover this precedence:

```dart
expect(todayState(orientationComplete: false).kind, FormationTodayKind.orientation);
expect(todayState(orientationComplete: true, profile: null).kind, FormationTodayKind.setup);
expect(todayState(profile: profile, recommendation: clicked).kind, FormationTodayKind.unresolved);
expect(todayState(profile: profile, recommendation: suggested).kind, FormationTodayKind.today);
expect(todayState(profile: profile, recommendation: completed).kind, FormationTodayKind.completed);
expect(todayState(profile: profile, currentDay: 71).kind, FormationTodayKind.maintenance);
```

Widget tests assert thumbnail semantics, title/creator/runtime, `Day 12 of 70`, **Watch today**, alternatives only when eligible, compact phone layout, 200% text scale, and no card transition animation when reduced motion is enabled.

`formation_today_state.dart` defines public `FormationTodayKind` and
`FormationTodayState` types plus the pure `todayState` resolver used by
the tests and `FormationTodayCard`.

- [ ] **Step 2: Verify card tests fail**

Run:

```powershell
flutter test test/features/daily_formation/daily_formation_card_test.dart test/features/formation/formation_today_card_test.dart
```

Expected: FAIL because the daily video state/card does not exist.

- [ ] **Step 3: Build the compact card and choice sheet**

Use a 16:9 thumbnail capped at 120 logical pixels high, warm-gold progress treatment, and raised ivory surface. Display one primary option. `FormationChoicesSheet` displays at most three distinct options with title, creator, runtime, lens label when material, and a selected indicator.

Do not expose an explicit sensitive-track name in the Today eyebrow or lock-screen-facing semantics. The visible focus may use the reviewed daily focus.

- [ ] **Step 4: Connect the existing Today formation state**

Keep orientation first. When complete, route a missing profile to setup. Otherwise resolve or show the current recommendation. Preserve the existing Scripture Formation card only inside Meditation; stop using its local completed-reading count as the post-orientation Today progression pointer.

- [ ] **Step 5: Run Today tests**

Run:

```powershell
flutter test test/features/daily_formation/daily_formation_card_test.dart test/features/formation/formation_today_card_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Today integration**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/application/formation_today_state.dart apps/soulbuddy/lib/features/daily_formation/presentation apps/soulbuddy/lib/features/formation/presentation/formation_today_card.dart apps/soulbuddy/test/features/daily_formation/daily_formation_card_test.dart apps/soulbuddy/test/features/formation/formation_today_card_test.dart
git commit -m "feat: present daily video formation on Today"
```

---

### Task 10: Launch exact videos and collect explicit completion

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/application/formation_video_launcher.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_checkin_sheet.dart`
- Create: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_completion_screen.dart`
- Modify: `apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_checkin_test.dart`
- Modify: `apps/soulbuddy/test/features/daily_formation/formation_test_fixtures.dart`

- [ ] **Step 1: Write failing launch and check-in tests**

```dart
test('records click only after the external launcher accepts the URL', () async {
  final events = <String>[];
  final launcher = FormationVideoLauncher(
    openExternal: (_) async => true,
    onClicked: (_, __) async => events.add('clicked'),
  );
  await launcher.watch(recommendation, option);
  expect(events, ['clicked']);
  expect(recommendation.status, isNot(FormationRecommendationStatus.completed));
});

testWidgets('finished advances while partial and not yet do not', (tester) async {
  await tester.pumpWidget(checkinHarness());
  await tester.tap(find.text('Finished'));
  await tester.pumpAndSettle();
  expect(repository.currentDay, 2);
});
```

Add launcher rejection, malformed URL, duplicate Finished tap, partial/resume, not-yet, skip, replace, and offline persistence tests.

The test file defines `checkinHarness()` with a fake repository whose
`currentDay` and event list are observable, and obtains `recommendation` and
`option` from the shared reviewed fixture.

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/features/daily_formation/formation_checkin_test.dart`

Expected: FAIL because launcher and check-in do not exist.

- [ ] **Step 3: Add exact external launch behavior**

Validate the option URI against its captured YouTube ID, call `launchUrl(uri, mode: LaunchMode.externalApplication)`, and only then write `video_clicked` plus `clickedAt` and `checkinDueAt = clickedAt + runtime + 5 minutes`. A launch failure leaves status unchanged and shows **Video could not open. Try again.**

- [ ] **Step 4: Build the check-in and completion experiences**

Check-in actions call the repository methods directly. Disable actions while a mutation is pending. On Finished, navigate to `/formation/completed/:recommendationId`; this page offers the reviewed reflection prompt, **Write reflection**, **Speak reflection**, **Make this my action**, and **Done**. These actions are optional and do not alter video completion.

- [ ] **Step 5: Run launch/check-in tests**

Run: `flutter test test/features/daily_formation/formation_checkin_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit explicit completion flow**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/application/formation_video_launcher.dart apps/soulbuddy/lib/features/daily_formation/presentation/formation_checkin_sheet.dart apps/soulbuddy/lib/features/daily_formation/presentation/formation_completion_screen.dart apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart apps/soulbuddy/lib/app/router.dart apps/soulbuddy/test/features/daily_formation/formation_checkin_test.dart
git commit -m "feat: confirm daily video completion"
```

---

### Task 11: Schedule daily alarms and runtime-based check-ins

**Files:**
- Create: `apps/soulbuddy/lib/features/daily_formation/application/daily_formation_reminder_coordinator.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/domain/prayer_reminder.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart`
- Modify: `apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart`
- Modify: `apps/soulbuddy/lib/app/app.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/daily_formation_reminder_coordinator_test.dart`

- [ ] **Step 1: Write failing coordinator tests**

```dart
test('schedules one recurring local alarm and one pending check-in', () async {
  await coordinator.start();
  expect(scheduler.requests.where((r) => r.kind == ReminderNotificationKind.dailyFormationAlarm), hasLength(1));
  expect(scheduler.requests.where((r) => r.kind == ReminderNotificationKind.dailyFormationCheckin), hasLength(1));
  expect(scheduler.requests.singleWhere((r) => r.kind == ReminderNotificationKind.dailyFormationCheckin).scheduledAtUtc, checkinDueAt);
});

test('finished cancels check-in and advances without a second event', () async {
  scheduler.emit(finishedResponse);
  await coordinator.settled;
  expect(scheduler.cancelled, contains(checkinNotificationId));
  expect(repository.dayAdvanceCount, 1);
});
```

Cover boot/package replacement reconciliation, timezone/DST changes, denied permission, notification duplicate responses, expired unresolved recommendation, soft follow-up cap, and generic sensitive-track copy.

The coordinator test file defines a recording scheduler, fake repository,
`finishedResponse`, `checkinDueAt`, and a `settled` future that completes after
the coordinator's serialized action queue drains.

- [ ] **Step 2: Verify coordinator tests fail**

Run: `flutter test test/features/daily_formation/daily_formation_reminder_coordinator_test.dart`

Expected: FAIL because notification kinds/coordinator do not exist.

- [ ] **Step 3: Extend notification contracts**

Add `dailyFormationAlarm` and `dailyFormationCheckin` kinds. Alarm actions: Open and Not now. Check-in actions: Finished, Watched some, Not yet. Keep notification title **Daily formation** and body **A focused lesson is ready** or **How did today’s lesson go?**; never include pack/struggle text.

- [ ] **Step 4: Implement reconciliation**

Observe profile/device delivery and current recommendation. Schedule a daily local-time alarm only after explicit enablement. Schedule one check-in at the stored UTC time. After no response, schedule at most one follow-up two hours later. Cancel check-ins on completion/replacement and reconstruct schedules after app startup or package replacement.

- [ ] **Step 5: Route notification responses**

Start the coordinator from `SoulBuddyApp`, route Open to Today, and apply Finished/Partial/Not-yet through the same idempotent repository methods as the in-app sheet.

- [ ] **Step 6: Run notification regression tests**

Run:

```powershell
flutter test test/features/daily_formation/daily_formation_reminder_coordinator_test.dart
flutter test test/features/prayers test/features/sacred_hours test/features/altar
```

Expected: PASS.

- [ ] **Step 7: Commit reminders**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/application/daily_formation_reminder_coordinator.dart apps/soulbuddy/lib/features/prayers/domain/prayer_reminder.dart apps/soulbuddy/lib/features/prayers/application/native_prayer_reminder_scheduler.dart apps/soulbuddy/lib/features/daily_formation/providers/daily_formation_providers.dart apps/soulbuddy/lib/app/app.dart apps/soulbuddy/test/features/daily_formation/daily_formation_reminder_coordinator_test.dart
git commit -m "feat: remind daily formation and check in"
```

---

### Task 12: Connect optional reflection, action, reconfiguration, and maintenance

**Files:**
- Modify: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_completion_screen.dart`
- Modify: `apps/soulbuddy/lib/features/daily_formation/presentation/formation_setup_screen.dart`
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/goals/presentation/daily_practice_sheet.dart`
- Create: `apps/soulbuddy/test/features/daily_formation/formation_completion_test.dart`
- Modify: `apps/soulbuddy/test/features/daily_formation/formation_setup_screen_test.dart`

- [ ] **Step 1: Write failing handoff and maintenance tests**

```dart
testWidgets('reflection opens capture with the reviewed daily prompt', (tester) async {
  await tester.pumpWidget(completionHarness(day: catalog.days[11]));
  await tester.tap(find.text('Write reflection'));
  expect(router.location, contains('/remember/capture'));
  expect(Uri.parse(router.location).queryParameters['prompt'], catalog.days[11].reflection);
});

testWidgets('day 70 offers maintenance without erasing history', (tester) async {
  await tester.pumpWidget(maintenanceHarness(completedDays: 70));
  expect(find.text('Continue growing'), findsOneWidget);
  await tester.tap(find.text('Strengthen a virtue'));
  expect(repository.completedEventCount, 70);
  expect(repository.currentMaintenanceMode, FormationMaintenanceMode.virtue);
});
```

Also test Speak reflection, action draft prefill/editability, duplicate-action protection, setup edits preserving unresolved recommendation, repeat-pack selection, weakest-pack calculation, and 30-day rhythm creation.

The completion test file defines `completionHarness()` and
`maintenanceHarness()` with a GoRouter test route table and in-memory repository;
the shared fixture supplies day 12 and a 70-day event history.

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/features/daily_formation/formation_completion_test.dart test/features/daily_formation/formation_setup_screen_test.dart`

Expected: FAIL because handoffs and maintenance state are absent.

- [ ] **Step 3: Connect Remember and Goal practice**

Pass `source=daily-formation`, recommendation ID, reviewed prompt, and date to `/remember/capture` with `mode=write` or `mode=speak`. Open the existing daily practice sheet with the reviewed action prefilled, editable, and a stable origin key formed as `formation:` followed by the recommendation ID so retries cannot create duplicates.

- [ ] **Step 4: Add maintenance choices and safe reconfiguration**

After day 70, offer **Repeat a focus**, **Strengthen a virtue**, and **30-day rhythm**. Compute weakest pack by completion/partial/skip event ratios with stable pack-order tie breaking; do not present that score as moral judgment. Saving changed settings increments configuration version, preserves completed/active queue entries, and rebuilds future entries.

- [ ] **Step 5: Run completion and related feature tests**

Run:

```powershell
flutter test test/features/daily_formation/formation_completion_test.dart test/features/daily_formation/formation_setup_screen_test.dart
flutter test test/features/record test/features/goals
```

Expected: PASS.

- [ ] **Step 6: Commit handoffs and maintenance**

```powershell
git add apps/soulbuddy/lib/features/daily_formation/presentation apps/soulbuddy/lib/features/record/presentation/record_screen.dart apps/soulbuddy/lib/features/goals/presentation/daily_practice_sheet.dart apps/soulbuddy/test/features/daily_formation
git commit -m "feat: continue formation through reflection and action"
```

---

### Task 13: Run full verification, deploy API, install Android build, and stage Play draft

**Files:**
- Modify only files required by failures directly caused by Tasks 1–12.

- [ ] **Step 1: Verify the workbook and generated snapshots**

Run:

```powershell
python -m unittest tools/formation/test_import_daily_formation.py -v
python "$env:USERPROFILE\.agents\skills\xlsx\scripts\recalc.py" content\formation\SoulBuddy_Daily_Video_Progression_v3.xlsx 60
Get-FileHash services\api\resources\formation\daily_formation_v1.json
Get-FileHash apps\soulbuddy\assets\content\daily_formation_v1.json
```

Expected: tests PASS, workbook reports zero formula errors, and both JSON SHA256 hashes match.

- [ ] **Step 2: Verify the complete API**

Run from `services/api`:

```powershell
php artisan test
vendor\bin\pint --test
php artisan migrate:fresh --force
php artisan formation:publish resources\formation\daily_formation_v1.json
```

Expected: all tests PASS, Pint reports no style failures, migrations complete, and catalog publication reports `44 videos, 10 packs, 70 days`.

- [ ] **Step 3: Verify the complete Flutter app**

Run from `apps/soulbuddy`:

```powershell
flutter test
flutter analyze
flutter build apk --debug
flutter build appbundle --release --build-number 6
```

Expected: all tests PASS, `No issues found`, APK produced, and signed AAB produced with version code 6. If Play Console already contains version code 6, query the existing tracks and use the next unused integer.

- [ ] **Step 4: Deploy API catalog and migrations**

Use the existing sbuddy deployment workflow to upload the committed API revision, run `php artisan migrate --force`, run `php artisan formation:publish resources/formation/daily_formation_v1.json`, and verify:

```powershell
Invoke-RestMethod https://sbuddy.elbiblio.com/api/formation/catalog | Select-Object -ExpandProperty data | Select-Object version,sourceSha256
```

Expected: published version and checksum match the bundled manifest.

Apply `services/api/docs/powersync-daily-formation-sync-rules.yaml` to the
connected PowerSync instance, validate the rules, and confirm a test
installation receives only rows whose `owner_id` matches its authenticated
owner claim.

- [ ] **Step 5: Install and verify on the connected Android device**

Run:

```powershell
adb devices
adb install -r -d build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p app.soulbuddy.soulbuddy -c android.intent.category.LAUNCHER 1
```

Verify manually on-device: orientation precedence, setup, reordered pack queue, video launch, runtime-based check-in, notification actions with app backgrounded, offline restart, large text, reconfiguration preserving progress, and day completion.

- [ ] **Step 6: Upload the release AAB as a Play production draft**

Use the authorized Google Play service account and existing draft-release script/config. Upload `build/app/outputs/bundle/release/app-release.aab` without publishing or promoting it. Verify the Play API returns draft status and the expected version code.

- [ ] **Step 7: Commit any verification-only fixes and push**

```powershell
git status --short
git add -u
git commit -m "fix: complete daily formation verification"
git push origin HEAD
```

If no fixes were required, skip the empty commit and push the existing task commits.
