# Covenant and Grace Visual System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SoulBuddy's rejected botanical presentation with a sacred, natural-slab visual system whose inscriptions reflect factual Pray, Act, and Remember responses for the displayed day.

**Architecture:** A code-native `CovenantSlabs` component renders only presentation state. A `DailyPracticeState` provider projects synchronized prayer-session, Today-action, and local daily-remembrance records for one displayed local date. Library and personal prayers both gain factual prayer-session support so the Pray inscription never mistakes selection for prayer.

**Tech Stack:** Flutter 3 / Dart 3, Riverpod, PowerSync SQLite, Laravel 12, CustomPainter, Source Serif 4 (SIL OFL 1.1), Flutter widget/golden/integration tests.

---

## File map

**Create**

- `apps/soulbuddy/assets/fonts/SourceSerif4Display-Semibold.ttf` — bundled sacred display face.
- `apps/soulbuddy/assets/fonts/OFL-SourceSerif4.txt` — required font license.
- `apps/soulbuddy/lib/core/design/covenant_grace_tokens.dart` — three-layer visual tokens.
- `apps/soulbuddy/lib/core/presentation/covenant_slabs.dart` — deterministic natural-slab painter and animation.
- `apps/soulbuddy/lib/features/today/domain/daily_practice_state.dart` — available/completed practice model.
- `apps/soulbuddy/lib/features/today/providers/daily_practice_providers.dart` — displayed-date projection.
- `apps/soulbuddy/test/core/presentation/covenant_slabs_test.dart` — painter, semantics, and motion contract.
- `apps/soulbuddy/test/features/today/daily_practice_state_test.dart` — real-database projection tests.
- `services/api/database/migrations/2026_08_13_000000_support_library_prayer_sessions.php` — exactly-one prayer source.

**Modify**

- `apps/soulbuddy/pubspec.yaml`, `lib/core/design/app_colors.dart`, `app_type.dart`, `app_theme.dart` — foundations.
- `apps/soulbuddy/lib/core/database/app_schema.dart` — library prayer sessions.
- `apps/soulbuddy/lib/features/prayers/domain/prayer_session.dart` — source-neutral session model.
- `apps/soulbuddy/lib/features/prayers/domain/today_prayer.dart` and its query — retain the selected personal prayer revision needed for a factual session.
- `apps/soulbuddy/lib/features/prayers/data/prayer_practice_repository.dart` and `powersync_prayer_practice_repository.dart` — library/personal sessions and daily watch.
- `apps/soulbuddy/lib/features/prayers/providers/prayer_practice_providers.dart` — daily-session provider.
- `services/api/app/Domain/Sync/ApplyPrayerPracticeMutation.php`, `app/Models/PrayerSession.php`, and sync tests — server validation and ownership.
- `apps/soulbuddy/lib/features/today/presentation/today_screen.dart` and `today_start_guide.dart` — focal daily flow.
- `apps/soulbuddy/lib/features/prayers/presentation/prayers_screen.dart`, `prayer_library_intro.dart`, and `prayer_library_tile.dart` — compact first use.
- Record presentation is intentionally owned by the companion private-audio plan so its new Speak control is functional in the same commit that introduces it.
- `apps/soulbuddy/lib/features/remember/presentation/remember_screen.dart`, `encounter_list_tile.dart`, and `daily_remembrance_card.dart` — living records.
- `apps/soulbuddy/lib/features/circles/presentation/circles_screen.dart` — gathered inscription marks.
- Existing visual and flow tests — new contract.

**Delete after references are removed**

- `apps/soulbuddy/lib/core/design/living_vine_tokens.dart`
- `apps/soulbuddy/lib/core/presentation/living_vine.dart`
- `apps/soulbuddy/test/core/presentation/living_vine_test.dart`
- `apps/soulbuddy/assets/images/soulbuddy_olive_memorial.webp`
- `apps/soulbuddy/test/core/design/signature_illustration_asset_test.dart`

### Task 1: Establish Covenant and Grace design foundations

**Files:** foundations and font assets listed above.

- [ ] **Step 1: Write failing token and typography tests**

Extend `apps/soulbuddy/test/core/design/app_theme_test.dart`:

```dart
test('Covenant and Grace tokens are installed in both themes', () {
  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    final colors = theme.extension<CovenantGraceColors>();
    expect(colors, isNotNull);
    expect(colors!.limestone.computeLuminance(), isNot(equals(0)));
    expect(theme.textTheme.headlineMedium!.fontFamily, 'Source Serif 4 Display');
    expect(theme.textTheme.bodyLarge!.fontFamily, isNot('Source Serif 4 Display'));
  }
});
```

Add a license/asset test that reads the two TTF/OFL paths and asserts they are nonempty and the license contains `SIL OPEN FONT LICENSE Version 1.1`.

- [ ] **Step 2: Run the focused test and observe RED**

Run:

```powershell
cd apps/soulbuddy
flutter test test/core/design/app_theme_test.dart
```

Expected: compile failure for `CovenantGraceColors` or missing font assets.

- [ ] **Step 3: Add exact tokens and bundled font**

Download unmodified upstream files:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/adobe-fonts/source-serif/release/TTF/SourceSerif4Display-Semibold.ttf -OutFile apps/soulbuddy/assets/fonts/SourceSerif4Display-Semibold.ttf
Invoke-WebRequest https://raw.githubusercontent.com/adobe-fonts/source-serif/release/LICENSE.md -OutFile apps/soulbuddy/assets/fonts/OFL-SourceSerif4.txt
```

Declare the font in `pubspec.yaml`:

```yaml
  fonts:
    - family: Source Serif 4 Display
      fonts:
        - asset: assets/fonts/SourceSerif4Display-Semibold.ttf
          weight: 600
```

Create `CovenantGraceColors` with light values `parchment #F7F1E5`, `limestone #C9BCA5`, `limestoneLight #E7DDCB`, `umber #62513F`, `covenantGold #B5893E`, `lightWash #F1DFB7`, and dark counterparts `#171B18`, `#756B5B`, `#9B8E78`, `#E1D4BF`, `#D6AB60`, `#4A3C25`. Implement `copyWith` and `lerp` as a normal `ThemeExtension`.

Set only `displaySmall`, `headlineMedium`, and `titleLarge` to `fontFamily: 'Source Serif 4 Display'`; keep body/control roles on the platform sans. Reduce mobile `headlineMedium` from 28 to 26 and keep body metrics unchanged.

- [ ] **Step 4: Run format and focused GREEN**

```powershell
cd apps/soulbuddy
dart format lib/core/design test/core/design
flutter test test/core/design/app_theme_test.dart
```

Expected: all theme tests pass; no network font dependency.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/assets/fonts apps/soulbuddy/pubspec.yaml apps/soulbuddy/lib/core/design apps/soulbuddy/test/core/design/app_theme_test.dart
git commit -m "feat: establish Covenant and Grace foundations"
```

### Task 2: Build the natural-slab visual primitive

**Files:** `covenant_slabs.dart`, its test, and golden fixtures.

- [ ] **Step 1: Write failing component tests**

Define the expected public API in the test:

```dart
const state = DailyPracticeState(
  available: {DailyPractice.pray, DailyPractice.act, DailyPractice.remember},
  completed: {DailyPractice.pray, DailyPractice.act},
);

await tester.pumpWidget(testHost(
  const CovenantSlabs(key: Key('slabs'), state: state, animate: true),
));

expect(find.bySemanticsLabel(
  'Today: prayer and action completed; remembrance available',
), findsOneWidget);
final paint = tester.widget<CustomPaint>(find.descendant(
  of: find.byKey(const Key('slabs')),
  matching: find.byType(CustomPaint),
));
expect((paint.painter! as CovenantSlabsPainter).state, state);
```

Also test zero/one/two/all completion, an unavailable action excluded from `2 of 2`, dark theme, 200% text, and `disableAnimations: true` yielding final progress immediately.

- [ ] **Step 2: Run focused RED**

```powershell
cd apps/soulbuddy
flutter test test/core/presentation/covenant_slabs_test.dart
```

Expected: missing `CovenantSlabs`, `DailyPractice`, and `DailyPracticeState`.

- [ ] **Step 3: Implement the model and painter**

Create the immutable model:

```dart
enum DailyPractice { pray, act, remember }

@immutable
class DailyPracticeState {
  const DailyPracticeState({required this.available, required this.completed})
      : assert(completed.difference(available).isEmpty);
  final Set<DailyPractice> available;
  final Set<DailyPractice> completed;
  int get completedCount => completed.length;
  int get availableCount => available.length;
}
```

`CovenantSlabsPainter` must use two fixed, deterministic polygon `Path`s—no `RRect`, random numbers, rounded top, cracks, numerals, or text glyphs. Paint warm light before inscriptions. Map Pray and Act to the left slab and Remember to the right; unavailable beds render at 25% opacity and completed lines reveal with `PathMetric.extractPath`.

Animate only when `oldWidget.state.completed != widget.state.completed`, for 360 ms; initialize at 1.0 so first paint never pretends a historical completion just occurred. Reduced motion sets progress to 1.0 immediately.

- [ ] **Step 4: Run component tests and golden checks**

```powershell
cd apps/soulbuddy
dart format lib/core/presentation/covenant_slabs.dart lib/features/today/domain/daily_practice_state.dart test/core/presentation/covenant_slabs_test.dart
flutter test test/core/presentation/covenant_slabs_test.dart
```

Expected: all state/semantics/motion tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/core/presentation/covenant_slabs.dart apps/soulbuddy/lib/features/today/domain/daily_practice_state.dart apps/soulbuddy/test/core/presentation/covenant_slabs_test.dart
git commit -m "feat: add natural covenant slab visual"
```

### Task 3: Make prayer sessions source-neutral and factual

**Files:** Flutter schema/domain/repository tests and Laravel migration/model/sync tests.

- [ ] **Step 1: Add Laravel RED coverage**

In `PrayerPracticeMutationTest.php`, add cases proving:

```php
it('accepts a session for one owned library prayer source', function () {
    $response = $this->actingAs($user)->postJson('/api/sync/mutations', [
        'operations' => [practiceOperation($operationId, 'prayer_sessions', $sessionId, [
            'library_prayer_id' => seededPrayerId(),
            'personal_prayer_id' => null,
            'prayer_revision_id' => null,
            'reminder_id' => null,
            'reminder_occurrence_key' => null,
            'source' => 'manual',
            'occurred_at' => '2026-08-13T07:00:00.000Z',
            'local_date' => '2026-08-13',
            'timezone' => 'Africa/Lagos',
            'device_id' => 'device-1',
            'retracted_at' => null,
        ])],
    ]);
    $response->assertOk()->assertJsonPath('accepted', 1);
});
```

Add rejection for zero sources, both sources, archived/missing library prayer, personal session without revision, reminder session with a library source, foreign records, replay conflict, and retraction after five minutes.

- [ ] **Step 2: Run Laravel RED**

```powershell
cd services/api
php artisan test --filter=PrayerPracticeMutationTest
```

Expected: new library-session cases fail because the column and validation do not exist.

- [ ] **Step 3: Implement the migration and server validation**

Migration requirements:

```php
Schema::table('prayer_sessions', function (Blueprint $table) {
    $table->uuid('library_prayer_id')->nullable()->after('user_id');
    $table->uuid('personal_prayer_id')->nullable()->change();
    $table->uuid('prayer_revision_id')->nullable()->change();
    $table->foreign('library_prayer_id')->references('id')->on('library_prayers')->cascadeOnDelete();
    $table->index(['user_id', 'library_prayer_id', 'local_date', 'retracted_at']);
    $table->index(['user_id', 'personal_prayer_id', 'local_date', 'retracted_at']);
});
```

Replace the session integrity check on SQLite and PostgreSQL with:

```sql
(
  (library_prayer_id IS NOT NULL AND personal_prayer_id IS NULL AND prayer_revision_id IS NULL)
  OR
  (library_prayer_id IS NULL AND personal_prayer_id IS NOT NULL AND prayer_revision_id IS NOT NULL)
)
AND (
  (source = 'manual' AND reminder_id IS NULL AND reminder_occurrence_key IS NULL)
  OR
  (source = 'reminder' AND library_prayer_id IS NULL AND reminder_id IS NOT NULL AND reminder_occurrence_key IS NOT NULL)
)
```

Update `ApplyPrayerPracticeMutation` validation and lock all referenced prayers in stable UUID order. Authorize only published, non-archived library prayers and owned active personal prayers. Update `sessionMatches` to compare nullable fields exactly.

- [ ] **Step 4: Implement Flutter schema and repository API**

Change the repository contract to:

```dart
Stream<bool> watchSessionForDate(PrayerReference prayer, DateTime localDate);

Future<PrayerSession> recordSession({
  required PrayerReference prayer,
  required String timezone,
  String? revisionId,
  String? reminderId,
  String? occurrenceKey,
});
```

`PrayerSession` stores `PrayerReference prayer` and nullable `prayerRevisionId`. `recordSession` requires a revision for personal prayers and forbids it for library prayers. The insert writes exactly one of `library_prayer_id` or `personal_prayer_id`. The daily watcher scopes `owner_id`, `local_date`, exact source, and `retracted_at IS NULL`.

Update reminder callers to pass `PrayerReference.personal(personalPrayerId)` and the immutable revision ID.

Extend `TodayPrayer` with `String? prayerRevisionId`. In `watchToday`, select `NULL AS prayer_revision_id` for library rows and `revision.id AS prayer_revision_id` for personal rows. This preserves the immutable source required when `I prayed this` records a personal prayer; callers pass null only for a library prayer.

- [ ] **Step 5: Run focused Flutter and Laravel GREEN**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_practice_repository_test.dart test/features/prayers/personal_prayer_practice_ui_test.dart
cd ../../services/api
vendor/bin/pint
php artisan test --filter=PrayerPracticeMutationTest
```

Expected: both suites pass, including real PowerSync database coverage.

- [ ] **Step 6: Commit**

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/prayers apps/soulbuddy/test/features/prayers services/api/app services/api/database/migrations services/api/tests/Feature/Sync/PrayerPracticeMutationTest.php
git commit -m "feat: record sessions for every prayer source"
```

### Task 4: Project Pray, Act, and Remember for the displayed date

**Files:** daily-practice provider/model tests and Today providers.

- [ ] **Step 1: Write a real-database RED test**

Seed a Today prayer for `2026-08-13`, one non-retracted matching session, `action_completed = 1`, and a remembered occurrence. Assert:

```dart
expect(
  await repository.watch(DateTime(2026, 8, 13)).first,
  const DailyPracticeState(
    available: {DailyPractice.pray, DailyPractice.act, DailyPractice.remember},
    completed: {DailyPractice.pray, DailyPractice.act, DailyPractice.remember},
  ),
);
```

Add cases for absent action, absent remembrance, retracted session, replacement prayer, and a stale prior date.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/today/daily_practice_state_test.dart
```

Expected: provider/repository is missing.

- [ ] **Step 3: Implement the projection**

Create one Riverpod provider keyed by the existing `todayPrayerDateProvider`. Combine:

- `todayPrayerProvider` for selected source, action availability, and action completion;
- `prayerSessionForDateProvider((reference, date))` for factual prayer completion;
- `dailyMemoryProvider` for remembrance availability and `remembered` status.

Use `switch`/records to wait for matching `AsyncData` values. Never reuse a completion from a different prayer or date. Expose errors as `AsyncError` and no hidden default completion.

- [ ] **Step 4: Run GREEN**

```powershell
cd apps/soulbuddy
dart format lib/features/today test/features/today/daily_practice_state_test.dart
flutter test test/features/today/daily_practice_state_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/today apps/soulbuddy/test/features/today/daily_practice_state_test.dart
git commit -m "feat: project daily spiritual practices"
```

### Task 5: Redesign Today around one sacred focal flow

**Files:** Today presentation and tests.

- [ ] **Step 1: Rewrite Today widget tests to RED**

Replace olive/vine expectations with:

```dart
expect(find.byKey(const Key('today-covenant-slabs')), findsOneWidget);
expect(find.text('Remember what God has done.'), findsOneWidget);
expect(find.text('Choose a prayer'), findsOneWidget);
expect(find.text('Record something'), findsOneWidget);
expect(find.byType(LivingVine), findsNothing);
```

For selected content, tap `I prayed this`, assert repository insertion and the Pray inscription; complete Act and Remember and assert `3 of 3 practices completed`. Keep stale-date, replacement, pending-write, error, compact 320×640, and 200% text tests.

- [ ] **Step 2: Run Today RED**

```powershell
cd apps/soulbuddy
flutter test test/features/today/today_prayer_test.dart test/features/remember/daily_remembrance_card_test.dart
```

- [ ] **Step 3: Implement the Today composition**

Use this order:

```text
Today / Pray. Act. Remember.
CovenantSlabs + textual daily status
selected prayer + I prayed this
practical action
daily remembrance
```

The empty copy is exactly:

```text
Remember what God has done.
Begin with prayer, then carry what you receive into action.
```

Primary action: `Choose a prayer`; secondary action: `Record something`. Remove the large bordered guide card and floating settings circle from the focal region. Route settings through a compact app-bar action with a 48 px target.

Use existing semantic feedback for session completion. Do not add a new sound. Disable duplicate taps while writes are pending and bind writes to the displayed date and prayer reference.

- [ ] **Step 4: Run focused GREEN and accessibility tests**

```powershell
cd apps/soulbuddy
dart format lib/features/today test/features/today/today_prayer_test.dart
flutter test test/features/today/today_prayer_test.dart test/features/remember/daily_remembrance_card_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features/today apps/soulbuddy/test/features/today apps/soulbuddy/test/features/remember/daily_remembrance_card_test.dart
git commit -m "feat: make Today a covenant practice flow"
```

### Task 6: Carry the visual language across Prayers, Remember, and Circles

**Files:** the four feature presentations and their tests.

- [ ] **Step 1: Write visual hierarchy RED tests**

Assert:

- Prayers shows `Library` and `Personalized` before any large teaching card, with no `Prayer is communion` card.
- Remember's empty primary action fits a 320×640 shell without scrolling and has no `remember-living-vine`.
- Circles has one gathered-inscription visual, keeps `Only you · saved on this device`, and has no intertwined branches.
- No rendered text or semantic label contains vine, branch, blossom, fruit, olive tree, memorial stone, score, streak, or leaderboard.

- [ ] **Step 2: Run the feature RED suites**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_library_flow_test.dart test/features/record/record_remember_flow_test.dart test/features/circles/circles_flow_test.dart
```

- [ ] **Step 3: Implement compact, non-card-heavy layouts**

Prayers uses a compact segmented choice and collapsible filters. The companion private-audio plan owns Record's final two 56 px `Speak`/`Write` capture-method tiles, compact memory-type choices, and framework-grounded copy; this plan does not add or expose an intermediate Record control.

Remember uses type/date/title and a shallow incised divider; promise/covenant entries may show the small paired-slab mark. Circles uses three short illuminated line marks painted by a dedicated decorative variant—not duplicate tablet cards—and retains privacy copy.

- [ ] **Step 4: Run focused GREEN at normal and 200% text**

```powershell
cd apps/soulbuddy
dart format lib/features/prayers/presentation lib/features/remember/presentation lib/features/circles/presentation
flutter test test/features/prayers/prayer_library_flow_test.dart test/features/record/record_remember_flow_test.dart test/features/circles/circles_flow_test.dart
```

- [ ] **Step 5: Commit**

```powershell
git add apps/soulbuddy/lib/features apps/soulbuddy/test/features
git commit -m "feat: extend Covenant and Grace across journeys"
```

### Task 7: Remove the rejected visual system and verify production surfaces

**Files:** old implementation/assets/tests, pubspec, docs, integration scripts.

- [ ] **Step 1: Add a failing no-botanical contract test**

Create a test that reads `lib`, `test`, and `pubspec.yaml` and fails when production paths contain `LivingVine`, `living_vine`, `soulbuddy_olive_memorial`, or `today-signature-illustration`. Exclude superseded historical design documents.

- [ ] **Step 2: Run RED, then delete all old references and assets**

```powershell
cd apps/soulbuddy
flutter test test/core/design/covenant_grace_contract_test.dart
```

Remove the two Living Vine source files, two obsolete tests/assets, all imports, theme extension registration, and the olive image manifest entry. Mark the old visual plan as superseded if not already marked.

- [ ] **Step 3: Run full verification**

```powershell
scripts/verify.ps1
scripts/run_web_integration.ps1
cd apps/soulbuddy
flutter build apk --debug
```

Expected: formatting, analysis, all Flutter tests, web build, Composer validation/audit, Pint, Laravel tests, all Chrome flows, and APK build pass.

- [ ] **Step 4: Inspect emulator and physical device**

Install without clearing data:

```powershell
flutter devices
flutter install -d A5CS024315010411 --debug
```

Capture Today, Prayers, Record, Remember, and Circles on an Android emulator and the connected physical device. Verify: natural non-rounded slabs; useful action above fold; no oversized blank region; no branch/tree/fruit image; no grave-like upright slab; readable 200% text; dark theme; reduced motion; daily completion and undo bound to the displayed date.

- [ ] **Step 5: Commit final cleanup**

```powershell
git add -A apps/soulbuddy docs scripts services/api
git diff --cached --check
git commit -m "feat: complete Covenant and Grace visual migration"
```

## Plan completion gate

Do not call the combined experience complete until Task 7 is green and the working Speak/Write Record experience from the companion plan is also green. The two plans may use separate commits, but the user-facing branch must never expose a dead Speak control.
