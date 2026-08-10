# SoulBuddy Foundation and Local-First Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable SoulBuddy slice in which a person can open the Flutter app, record an Encounter locally, see it immediately in Remember, reopen it offline, link an RSVCE passage, and synchronize through a policy-enforced Laravel mutation contract when PowerSync is configured.

**Architecture:** A Flutter feature-oriented application reads and writes an encrypted PowerSync-managed SQLite database through small repository interfaces. Laravel 13 is the authoritative modular monolith for identity, policy enforcement, idempotent mutation application, and PostgreSQL persistence; the PowerSync service URL remains environment-configured so local UI and repository tests do not depend on a running sync service. RSVCE is a separate read-only SQLite source prepared from the existing local database and accessed only through `ScriptureRepository`.

**Tech Stack:** Flutter 3.35 / Dart 3.9, Riverpod, go_router 17.2.x, PowerSync 1.17.0 with Core 1.7.0 (source-compatible with Dart 3.9; upgrade to 2.x with Dart 3.10+), sqlite3, UUIDv7, Laravel 13 / PHP 8.3, Pest, PostgreSQL production, SQLite backend tests, Flutter test, Alchemist, Patrol (integration scaffold).

---

## File structure

```text
apps/soulbuddy/
  assets/fonts/
  assets/scripture/rsvce.db                 # generated locally, gitignored
  lib/app/app.dart
  lib/app/router.dart
  lib/core/database/app_database.dart
  lib/core/database/app_schema.dart
  lib/core/design/app_colors.dart
  lib/core/design/app_spacing.dart
  lib/core/design/app_theme.dart
  lib/core/design/app_type.dart
  lib/core/sync/sync_status.dart
  lib/features/today/presentation/today_screen.dart
  lib/features/prayers/presentation/prayers_screen.dart
  lib/features/record/domain/encounter.dart
  lib/features/record/domain/encounter_draft.dart
  lib/features/record/data/encounter_repository.dart
  lib/features/record/data/powersync_encounter_repository.dart
  lib/features/record/presentation/record_screen.dart
  lib/features/remember/presentation/remember_screen.dart
  lib/features/circles/presentation/circles_screen.dart
  lib/features/scripture/domain/scripture_passage.dart
  lib/features/scripture/data/scripture_repository.dart
  lib/features/scripture/data/sqlite_scripture_repository.dart
  lib/main.dart
  test/core/design/app_theme_test.dart
  test/features/record/encounter_repository_test.dart
  test/features/record/record_remember_flow_test.dart
  test/features/scripture/sqlite_scripture_repository_test.dart
services/api/
  app/Domain/Encounters/ApplyEncounterMutation.php
  app/Http/Controllers/Api/SyncMutationController.php
  app/Http/Requests/SyncMutationBatchRequest.php
  app/Models/Encounter.php
  app/Models/EncounterRevision.php
  app/Models/SyncOperation.php
  app/Policies/EncounterPolicy.php
  database/migrations/*_create_encounters_table.php
  database/migrations/*_create_encounter_revisions_table.php
  database/migrations/*_create_sync_operations_table.php
  routes/api.php
  tests/Feature/Sync/EncounterMutationTest.php
tool/prepare_rsvce.ps1
scripts/verify.ps1
```

The Flutter app owns interaction and offline state. The API owns authorization and permanent server state. Scripture stays outside both synced stores.

### Task 1: Bootstrap the monorepo and pin compatible dependencies

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Generate: `apps/soulbuddy/**`
- Generate: `services/api/**`
- Create: `scripts/verify.ps1`

- [x] **Step 1: Add repository ignore rules**

Create `.gitignore` with:

```gitignore
.worktrees/
.dart_tool/
.idea/
.vscode/
build/
coverage/
*.iml
*.log
.env
.env.*
!.env.example
vendor/
node_modules/
apps/soulbuddy/assets/scripture/*.db
services/api/database/database.sqlite
```

- [x] **Step 2: Generate Flutter application boilerplate**

Run:

```powershell
New-Item -ItemType Directory -Force apps | Out-Null
flutter create --org app.soulbuddy --platforms android,ios,web --project-name soulbuddy apps/soulbuddy
```

Expected: Flutter creates the application and `flutter test apps/soulbuddy` passes its generated test.

- [x] **Step 3: Add Flutter runtime and test dependencies**

Run from `apps/soulbuddy`:

```powershell
flutter pub add flutter_riverpod go_router:^17.2.3 powersync:1.17.0 uuid:^4.5.2 sqlite3 path path_provider flutter_secure_storage
flutter pub add --dev alchemist accessibility_tools
```

Expected: dependency resolution succeeds on Dart 3.9.2. Add a `powersync_core: 1.7.0` dependency override: PowerSync 1.18/Core 1.8 uses a Dart 3.10-only annotation, while PowerSync 2.x pulls `sqlite3_web` releases that require Dart 3.10.

- [x] **Step 4: Generate Laravel application boilerplate**

Run:

```powershell
New-Item -ItemType Directory -Force services | Out-Null
composer create-project laravel/laravel:^13.0 services/api
Set-Location services/api
composer require laravel/sanctum
composer require pestphp/pest pestphp/pest-plugin-laravel --dev --with-all-dependencies
.\vendor\bin\pest --init
```

Expected: Laravel installs on PHP 8.3 and `php artisan test` passes.

- [x] **Step 5: Add the repository verification entrypoint**

Create `scripts/verify.ps1`:

```powershell
$ErrorActionPreference = 'Stop'

Push-Location "$PSScriptRoot\..\apps\soulbuddy"
try {
  flutter analyze
  flutter test
} finally {
  Pop-Location
}

Push-Location "$PSScriptRoot\..\services\api"
try {
  php artisan test
} finally {
  Pop-Location
}
```

- [x] **Step 6: Verify generated foundations**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`

Expected: Flutter analyze, Flutter tests, and Laravel tests exit successfully.

- [x] **Step 7: Commit the foundation**

```powershell
git add .gitignore README.md apps services scripts
git commit -m "build: bootstrap Flutter and Laravel workspaces"
```

### Task 2: Establish SoulBuddy's three-layer Flutter design system and application shell

**Files:**
- Create: `apps/soulbuddy/lib/core/design/app_colors.dart`
- Create: `apps/soulbuddy/lib/core/design/app_spacing.dart`
- Create: `apps/soulbuddy/lib/core/design/app_type.dart`
- Create: `apps/soulbuddy/lib/core/design/app_theme.dart`
- Create: `apps/soulbuddy/lib/app/router.dart`
- Create: `apps/soulbuddy/lib/app/app.dart`
- Create: five initial feature screens
- Modify: `apps/soulbuddy/lib/main.dart`
- Test: `apps/soulbuddy/test/core/design/app_theme_test.dart`
- Test: `apps/soulbuddy/test/app/app_navigation_test.dart`

- [x] **Step 1: Write failing design-token tests**

Create `test/core/design/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/design/app_colors.dart';
import 'package:soulbuddy/core/design/app_spacing.dart';
import 'package:soulbuddy/core/design/app_theme.dart';

void main() {
  test('uses a four-point primitive spacing scale', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 16);
    expect(AppSpacing.lg, 24);
    expect(AppSpacing.xl, 32);
  });

  test('maps semantic colors into component theme values', () {
    final ThemeData theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.action);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(theme.navigationBarTheme.height, 72);
    expect(theme.inputDecorationTheme.filled, isTrue);
  });
}
```

- [x] **Step 2: Run the token test and verify RED**

Run: `flutter test test/core/design/app_theme_test.dart`

Expected: FAIL because the design classes do not exist.

- [x] **Step 3: Implement primitive, semantic, and component tokens**

Use these primitive/semantic values:

```dart
abstract final class AppColors {
  static const canvas = Color(0xFFFBFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F5F2);
  static const ink = Color(0xFF1C2620);
  static const inkMuted = Color(0xFF59645E);
  static const action = Color(0xFF285943);
  static const actionStrong = Color(0xFF174334);
  static const accent = Color(0xFF9A6B2F);
  static const outline = Color(0xFFDDE3DE);
  static const danger = Color(0xFFB3261E);
}

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

Build `AppTheme.light()` with Material 3, a minimum 48dp interactive height, 12dp component radius, visible focus borders, restrained zero-or-low elevation, and semantic colors only. Use system typography for this milestone; bundled editorial fonts are a later isolated enhancement after startup measurements.

- [x] **Step 4: Run the token test and verify GREEN**

Run: `flutter test test/core/design/app_theme_test.dart`

Expected: PASS.

- [x] **Step 5: Write a failing navigation test**

Create `test/app/app_navigation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/app/app.dart';

void main() {
  testWidgets('shows all five top-level destinations', (tester) async {
    await tester.pumpWidget(const SoulBuddyApp());

    for (final label in ['Today', 'Prayers', 'Record', 'Remember', 'Circles']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Remember').last);
    await tester.pumpAndSettle();
    expect(find.text('What you have recorded'), findsOneWidget);
  });
}
```

- [x] **Step 6: Run navigation test and verify RED**

Run: `flutter test test/app/app_navigation_test.dart`

Expected: FAIL because `SoulBuddyApp` and routing do not exist.

- [x] **Step 7: Implement the application shell**

Implement `StatefulShellRoute.indexedStack` with exactly five branches. Use `NavigationBar` below 840 logical pixels and `NavigationRail` at or above 840. Keep destination state alive. Each placeholder screen has one semantic page title and concise explanatory copy; Record has the primary action.

- [x] **Step 8: Run navigation and full Flutter tests**

Run:

```powershell
flutter test test/app/app_navigation_test.dart
flutter test
flutter analyze
```

Expected: all commands exit successfully.

- [x] **Step 9: Commit design system and shell**

```powershell
git add apps/soulbuddy/lib apps/soulbuddy/test
git commit -m "feat: add SoulBuddy design system and app shell"
```

### Task 3: Implement the Encounter domain and local PowerSync repository

**Files:**
- Create: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Create: `apps/soulbuddy/lib/core/database/app_database.dart`
- Create: `apps/soulbuddy/lib/features/record/domain/encounter.dart`
- Create: `apps/soulbuddy/lib/features/record/domain/encounter_draft.dart`
- Create: `apps/soulbuddy/lib/features/record/data/encounter_repository.dart`
- Create: `apps/soulbuddy/lib/features/record/data/powersync_encounter_repository.dart`
- Test: `apps/soulbuddy/test/features/record/encounter_repository_test.dart`

- [x] **Step 1: Write the failing repository contract test**

The test opens a temporary local-only PowerSync database and asserts:

```dart
test('saves and watches an encounter without a network connection', () async {
  final repository = await harness.createRepository();
  final stream = repository.watchAll();

  await repository.create(const EncounterDraft(
    title: 'The help I received',
    body: 'I remembered that I was not alone.',
    occurredOn: '2026-08-10',
    isAltar: false,
  ));

  final encounters = await stream.firstWhere((items) => items.isNotEmpty);
  expect(encounters.single.title, 'The help I received');
  expect(encounters.single.syncState, EncounterSyncState.pending);
});
```

Add a second test that closes and reopens the same database path and confirms the record remains.

- [x] **Step 2: Run repository tests and verify RED**

Run: `flutter test test/features/record/encounter_repository_test.dart`

Expected: FAIL because the repository and schema do not exist.

- [x] **Step 3: Define the PowerSync client schema**

Define:

```dart
const appSchema = Schema([
  Table('encounters', [
    Column.text('owner_id'),
    Column.text('title'),
    Column.text('body'),
    Column.text('occurred_on'),
    Column.integer('is_altar'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('archived_at'),
    Column.text('current_revision_id'),
  ], indexes: [
    Index('encounters_owner_date', [
      IndexedColumn('owner_id'),
      IndexedColumn('occurred_on'),
    ]),
  ]),
  Table('encounter_revisions', [
    Column.text('encounter_id'),
    Column.text('owner_id'),
    Column.text('title'),
    Column.text('body'),
    Column.text('created_at'),
    Column.text('device_id'),
  ], indexes: [
    Index('encounter_revisions_parent', [IndexedColumn('encounter_id')]),
  ]),
  Table('sync_issues', [
    Column.text('record_type'),
    Column.text('record_id'),
    Column.text('code'),
    Column.text('message'),
    Column.text('created_at'),
    Column.text('resolved_at'),
  ]),
]);
```

Use client-generated UUIDv7 strings. Insert the Encounter and first revision in one local transaction. The repository returns reactive streams from `database.watch` and never performs an HTTP read.

- [x] **Step 4: Implement repository behavior minimally**

`EncounterRepository` exposes:

```dart
abstract interface class EncounterRepository {
  Stream<List<Encounter>> watchAll();
  Future<Encounter> create(EncounterDraft draft);
  Future<void> markAsAltar(String encounterId, {required bool value});
  Future<void> archive(String encounterId);
}
```

Persist ISO-8601 UTC timestamps and an injected owner/device identity. Do not introduce people, family, lessons, or audio in this slice.

- [x] **Step 5: Run repository tests and verify GREEN**

Run:

```powershell
flutter test test/features/record/encounter_repository_test.dart
flutter test
flutter analyze
```

Expected: all commands exit successfully.

- [x] **Step 6: Commit local Encounter persistence**

```powershell
git add apps/soulbuddy/lib/core/database apps/soulbuddy/lib/features/record apps/soulbuddy/test/features/record
git commit -m "feat: persist encounters locally with PowerSync"
```

### Task 4: Build the guided Record and Remember flow

**Files:**
- Modify: `apps/soulbuddy/lib/features/record/presentation/record_screen.dart`
- Modify: `apps/soulbuddy/lib/features/remember/presentation/remember_screen.dart`
- Create: `apps/soulbuddy/lib/features/record/presentation/encounter_form.dart`
- Create: `apps/soulbuddy/lib/features/remember/presentation/encounter_list_tile.dart`
- Create: `apps/soulbuddy/lib/features/record/providers/encounter_providers.dart`
- Test: `apps/soulbuddy/test/features/record/record_remember_flow_test.dart`

- [x] **Step 1: Write a failing offline interaction test**

Use a real temporary repository and override the Riverpod provider:

```dart
testWidgets('records an encounter and shows it in Remember immediately', (tester) async {
  await tester.pumpWidget(testApp(repository));
  await tester.tap(find.text('Record').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Encounter'));
  await tester.enterText(find.byKey(const Key('encounter-title')), 'A prayer was answered');
  await tester.enterText(find.byKey(const Key('encounter-body')), 'Help came through a person.');
  await tester.tap(find.text('Save encounter'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Remember').last);
  await tester.pumpAndSettle();
  expect(find.text('A prayer was answered'), findsOneWidget);
});
```

- [x] **Step 2: Run the interaction test and verify RED**

Run: `flutter test test/features/record/record_remember_flow_test.dart`

Expected: FAIL because the guided form is absent.

- [x] **Step 3: Implement the minimum guided flow**

Record first presents four 48dp choices: Encounter, Lesson, Commitment, Prayer. Only Encounter is active in this slice; the remaining choices display `Coming in the next milestone` without navigating to empty forms.

The Encounter form contains:

- required labelled title, maximum 120 characters;
- optional labelled body, maximum 4,000 characters;
- occurrence date defaulting to today;
- an optional `Keep this as an Altar` switch with the helper text `Mark an encounter you want to return to and remember.`;
- one primary `Save encounter` button.

Save locally, return to Record's confirmation state, and keep entered text if validation fails. Remember uses the repository stream and displays title, occurrence date, Altar label when applicable, and a helpful empty state.

- [x] **Step 4: Verify accessibility behavior**

Add widget assertions that text fields have labels, every target is at least 48dp high, Altar state is expressed in text rather than color alone, and the screen survives `textScaler: const TextScaler.linear(2)` without exceptions.

- [x] **Step 5: Run focused and full verification**

Run:

```powershell
flutter test test/features/record/record_remember_flow_test.dart
flutter test
flutter analyze
```

Expected: all commands exit successfully.

- [x] **Step 6: Commit Record and Remember**

```powershell
git add apps/soulbuddy/lib/features apps/soulbuddy/test/features
git commit -m "feat: add guided encounter recording and remembering"
```

### Task 5: Prepare and integrate the local RSVCE Scripture source

**Files:**
- Create: `tool/prepare_rsvce.ps1`
- Create locally: `apps/soulbuddy/assets/scripture/rsvce.db`
- Modify: `apps/soulbuddy/pubspec.yaml`
- Create: `apps/soulbuddy/lib/features/scripture/domain/scripture_passage.dart`
- Create: `apps/soulbuddy/lib/features/scripture/data/scripture_repository.dart`
- Create: `apps/soulbuddy/lib/features/scripture/data/sqlite_scripture_repository.dart`
- Create: `apps/soulbuddy/lib/features/scripture/presentation/scripture_passage_screen.dart`
- Test: `apps/soulbuddy/test/features/scripture/sqlite_scripture_repository_test.dart`

- [ ] **Step 1: Write failing Scripture repository tests**

Test against a tiny temporary SQLite fixture with the same source schema:

```dart
test('loads a chapter in canonical verse order', () async {
  final repository = await fixture.openRepository();
  final passage = await repository.chapter(book: 'Jn', chapter: 3);

  expect(passage.reference, 'John 3');
  expect(passage.verses.map((verse) => verse.number), orderedEquals([1, 2]));
});

test('returns a typed not-found result for an unknown reference', () async {
  final repository = await fixture.openRepository();
  expect(
    () => repository.chapter(book: 'Unknown', chapter: 1),
    throwsA(isA<ScriptureReferenceNotFound>()),
  );
});
```

- [ ] **Step 2: Run Scripture tests and verify RED**

Run: `flutter test test/features/scripture/sqlite_scripture_repository_test.dart`

Expected: FAIL because the repository is absent.

- [ ] **Step 3: Add the local preparation script**

`tool/prepare_rsvce.ps1` must:

1. accept `-Source` defaulting to `C:\dev\catholicdaily-flutter\assets\rsvce.db`;
2. resolve source and destination absolute paths;
3. fail before copying if the source is not a valid file;
4. copy to `apps/soulbuddy/assets/scripture/rsvce.db`;
5. use the available Python standard-library SQLite only to run `PRAGMA quick_check`, create `verses_lookup(book_id, chapter_id, verse_id)`, and write a local `soulbuddy_manifest` table with schema version and SHA-256;
6. print counts but never print verse text.

The generated DB remains gitignored.

- [ ] **Step 4: Run the preparation script and verify the pack**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tool/prepare_rsvce.ps1
```

Expected output includes `quick_check: ok`, `books: 73`, and `verses: 36083`.

- [ ] **Step 5: Implement the read-only repository**

`ScriptureRepository` exposes:

```dart
abstract interface class ScriptureRepository {
  Future<ScripturePassage> chapter({required String book, required int chapter});
  Future<ScripturePassage> verses({
    required String book,
    required int chapter,
    required int firstVerse,
    required int lastVerse,
  });
}
```

Resolve a book by `books.shortname`, then query `verses` with `book_id`, `chapter_id`, and verse bounds. The presentation labels quoted text as `RSVCE · Scripture`; it does not mix personal or generated wording into the quotation container.

- [ ] **Step 6: Run Scripture tests and query-plan verification**

Run focused tests, then use `EXPLAIN QUERY PLAN` in a repository test to assert the prepared database contains `verses_lookup` and avoids `SCAN v` for chapter lookup.

Expected: all Scripture tests pass and no verse-table scan is reported.

- [ ] **Step 7: Add a linked passage entry point**

Add a small `Open John 3` development fixture to Encounter detail only for this vertical slice. Route to the passage screen, preserve navigation state, and show a focused retry state if the Scripture database is unavailable.

- [ ] **Step 8: Run Flutter verification and commit**

```powershell
flutter test
flutter analyze
git add tool apps/soulbuddy/pubspec.yaml apps/soulbuddy/lib/features/scripture apps/soulbuddy/test/features/scripture
git commit -m "feat: add optimized local RSVCE Scripture access"
```

### Task 6: Implement Laravel's idempotent Encounter mutation contract

**Files:**
- Create: migrations and models listed above
- Create: `services/api/app/Domain/Encounters/ApplyEncounterMutation.php`
- Create: `services/api/app/Http/Requests/SyncMutationBatchRequest.php`
- Create: `services/api/app/Http/Controllers/Api/SyncMutationController.php`
- Create: `services/api/app/Policies/EncounterPolicy.php`
- Modify: `services/api/routes/api.php`
- Test: `services/api/tests/Feature/Sync/EncounterMutationTest.php`

- [ ] **Step 1: Write failing API feature tests**

Cover:

```php
it('applies an encounter and revision atomically', function () {
    $user = User::factory()->create();

    $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [[
            'operation_id' => '0198a000-0000-7000-8000-000000000001',
            'table' => 'encounters',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000002',
            'data' => [
                'title' => 'The help I received',
                'body' => 'I remembered that I was not alone.',
                'occurred_on' => '2026-08-10',
                'is_altar' => false,
                'current_revision_id' => '0198a000-0000-7000-8000-000000000003',
            ],
        ], [
            'operation_id' => '0198a000-0000-7000-8000-000000000004',
            'table' => 'encounter_revisions',
            'type' => 'put',
            'id' => '0198a000-0000-7000-8000-000000000003',
            'data' => [
                'encounter_id' => '0198a000-0000-7000-8000-000000000002',
                'title' => 'The help I received',
                'body' => 'I remembered that I was not alone.',
                'device_id' => 'test-device',
            ],
        ]],
    ])->assertOk()->assertJsonPath('accepted', 2);

    expect(Encounter::first()->user_id)->toBe($user->id)
        ->and(EncounterRevision::count())->toBe(1);
});
```

Also test duplicate `operation_id`, another user's update, unknown tables, invalid data, and a batch rollback when its Encounter/Revision pair is incomplete.

- [ ] **Step 2: Run the tests and verify RED**

Run: `php artisan test --filter=EncounterMutationTest`

Expected: FAIL because routes and models do not exist.

- [ ] **Step 3: Add migrations and constraints**

Use UUID primary keys, `user_id` foreign keys, indexed occurrence dates, soft archival timestamps, a unique operation ID, and a unique `(encounter_id, id)` revision relationship. Production migrations target PostgreSQL-compatible column types; tests use SQLite-compatible behavior.

- [ ] **Step 4: Implement the mutation service**

The request permits only `encounters` and `encounter_revisions` in this milestone. The authenticated user ID always comes from the server session, never client data. Wrap each submitted transaction group in `DB::transaction`, use `sync_operations.operation_id` for idempotency, run policies before update/archive, and return per-operation accepted or rejected results with HTTP 200. Reserve 422 for a structurally invalid batch and 5xx for transient infrastructure failures.

- [ ] **Step 5: Run focused and full backend tests**

Run:

```powershell
php artisan test --filter=EncounterMutationTest
php artisan test
```

Expected: all tests pass.

- [ ] **Step 6: Commit the mutation contract**

```powershell
git add services/api
git commit -m "feat: apply encounter sync mutations in Laravel"
```

### Task 7: Connect PowerSync uploads to Laravel without coupling the UI to connectivity

**Files:**
- Create: `apps/soulbuddy/lib/core/config/app_config.dart`
- Create: `apps/soulbuddy/lib/core/sync/laravel_backend_connector.dart`
- Create: `apps/soulbuddy/lib/core/sync/sync_issue.dart`
- Create: `apps/soulbuddy/lib/core/sync/sync_status.dart`
- Test: `apps/soulbuddy/test/core/sync/laravel_backend_connector_test.dart`
- Create: `services/api/app/Http/Controllers/Api/PowerSyncTokenController.php`
- Create: `services/api/tests/Feature/Sync/PowerSyncTokenTest.php`

- [ ] **Step 1: Write failing connector tests**

Use a local fake HTTP client to assert that:

- credentials are fetched from `/api/sync/token`;
- one PowerSync CRUD transaction becomes one Laravel mutation batch;
- a 503 throws and leaves the upload queue pending;
- a 200 response with a rejected operation completes the PowerSync batch and creates/receives a `sync_issues` row instead of blocking later writes;
- no prayer or Encounter body is logged.

- [ ] **Step 2: Run connector tests and verify RED**

Run: `flutter test test/core/sync/laravel_backend_connector_test.dart`

Expected: FAIL because the connector does not exist.

- [ ] **Step 3: Implement configuration and connector**

Read compile-time values:

```dart
const apiBaseUrl = String.fromEnvironment('SOULBUDDY_API_URL');
const powerSyncUrl = String.fromEnvironment('SOULBUDDY_POWERSYNC_URL');
```

An empty PowerSync URL keeps the database in local-only mode and never prevents startup. The backend connector implements `fetchCredentials` and `uploadData`; it has no presentation imports.

- [ ] **Step 4: Implement Laravel token endpoint**

Issue a short-lived JWT whose subject is the authenticated user's immutable public UUID and whose audience/issuer are environment-configured. Test authentication requirement, claims, expiration, and absence of private profile data.

- [ ] **Step 5: Verify connector and token behavior**

Run:

```powershell
flutter test test/core/sync/laravel_backend_connector_test.dart
php artisan test --filter=PowerSyncTokenTest
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Expected: all commands exit successfully.

- [ ] **Step 6: Commit the sync boundary**

```powershell
git add apps/soulbuddy/lib/core apps/soulbuddy/test/core services/api
git commit -m "feat: connect local writes to Laravel sync boundary"
```

### Task 8: Verify the vertical slice and document the runnable path

**Files:**
- Modify: `README.md`
- Modify: `scripts/verify.ps1`
- Create: `apps/soulbuddy/integration_test/offline_encounter_flow_test.dart`
- Create: `docs/architecture/local-first.md`

- [ ] **Step 1: Write the integration test**

The Patrol-compatible Flutter integration test uses local-only mode and performs:

`launch → Record → Encounter → save → Remember → terminate/relaunch → Remember → open Scripture`.

Assert that no network configuration is required and that entered text survives relaunch.

- [ ] **Step 2: Run the integration test and verify RED if unsupported setup remains**

Run on Chrome first:

```powershell
flutter test integration_test/offline_encounter_flow_test.dart -d chrome
```

Expected: the first run exposes any missing web SQLite assets or initialization path; fix only those failures before proceeding.

- [ ] **Step 3: Add web PowerSync assets and persistent-storage bootstrap**

Run `dart run powersync:setup_web --encryption`, add the custom service-worker registration required by the current Flutter web tooling, and request storage persistence only after the first important user save. Unit-test the Dart boundary and manually verify the browser permission outcome is handled whether granted or denied.

- [ ] **Step 4: Document architecture and setup**

`README.md` must contain exact Windows commands for:

- preparing RSVCE;
- running Flutter locally without sync;
- running Laravel with SQLite tests;
- configuring Postgres and PowerSync later through environment variables;
- running all verification.

`docs/architecture/local-first.md` documents local-first invariants, mutation error semantics, private-data logging exclusions, and the current absence of a local PowerSync service because Docker is not installed.

- [ ] **Step 5: Run full fresh verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
flutter test integration_test/offline_encounter_flow_test.dart -d chrome
git diff --check
git status --short
```

Expected: analysis and all tests pass; the only ignored generated artifact is the optimized RSVCE database; `git diff --check` reports no whitespace errors.

- [ ] **Step 6: Review acceptance criteria**

Confirm with evidence:

- local content renders without a network;
- Encounter creation updates Remember immediately;
- Encounter survives database reopen;
- concurrent revisions are preserved by model and backend tests;
- RSVCE chapter query uses the composite index;
- Laravel rejects unauthorized writes without blocking subsequent operations;
- web storage denial is recoverable;
- no private text appears in logs.

- [ ] **Step 7: Commit the verified vertical slice**

```powershell
git add README.md scripts docs/architecture apps/soulbuddy/integration_test apps/soulbuddy/web
git commit -m "docs: document verified local-first vertical slice"
```

## Execution notes

- 2026-08-10: Pinned `powersync` to 1.17.0 and `powersync_core` to 1.7.0. Dependency resolution first proved the 2.x line requires Dart 3.10 through `sqlite3_web`; compiling 1.18 then proved Core 1.8 also uses the Dart 3.10-only `Deprecated.subclass` annotation despite its broader declared SDK range. The selected pair compiles on the installed Flutter 3.35 / Dart 3.9 toolchain and preserves the upgrade path.
- 2026-08-10: Pest 4 uses `.\vendor\bin\pest --init`; the earlier `php artisan pest:install` command is no longer registered. The repository uses the current CLI initializer.
- 2026-08-10: The Record/Remember widget test uses a deterministic implementation of `EncounterRepository`. The dedicated repository suite already runs against the real PowerSync engine, including offline writes and database reopen persistence; combining a live PowerSync watcher with `flutter_tester` on Windows leaves the package's native watcher isolate alive after widget teardown. Separating contract and UI tests preserves coverage without hanging the test process.

- Work inline in the dedicated `C:\dev\soulbuddy` repository. It began as a new, clean repository for this product, so a linked worktree adds no protection at this stage.
- Do not install Docker Desktop as part of this plan. Its absence must not block local-first application development or contract tests.
- Do not commit the generated RSVCE database. The preparation script makes the local application copy reproducible from the user-provided source path.
- Do not add AI, Circles behavior, audio, people, family, lessons, or commitments during this plan.
- If a generated framework file needs a mechanical change, keep it within the task that owns the behavior and cover the behavior with the specified test.
