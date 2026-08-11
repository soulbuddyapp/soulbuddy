# Guided Prayer Personalization and AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an offline-first guided prayer request, authenticated DeepSeek draft generation, editable acceptance into immutable personal-prayer revisions, explicit Encounter/RSVCE context, and personal-prayer use in Today.

**Architecture:** Flutter stores generation requests and context snapshots in local-only PowerSync tables, then a lifecycle-aware dispatcher calls an authenticated Laravel endpoint when possible. Laravel owns prompt policy, DeepSeek access, output validation, rate limits, and short-lived encrypted idempotency; accepted prayers become private synchronized records with immutable revisions and typed Today selection. Reminder, narration, prayer-session, and publication work is intentionally excluded from this plan and follows only after this vertical slice passes its full Android and Chrome acceptance flow.

**Tech Stack:** Flutter 3 / Dart 3.9, Riverpod 3, GoRouter, PowerSync/SQLite, Laravel 13 / PHP 8.3, Sanctum, Laravel HTTP client and Cache, DeepSeek V4 Flash JSON output, Pest 4.

---

## File structure and ownership

### Flutter files to create

- `apps/soulbuddy/lib/features/prayers/domain/prayer_generation_request.dart` — generation enums, request state, context snapshots, and draft value types.
- `apps/soulbuddy/lib/features/prayers/domain/personal_prayer.dart` — accepted personal prayer, immutable revision, link, and display projection.
- `apps/soulbuddy/lib/features/prayers/domain/prayer_reference.dart` — typed library/personal reference used by Today.
- `apps/soulbuddy/lib/features/prayers/data/prayer_generation_repository.dart` — local queue interface.
- `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_generation_repository.dart` — transactional local-only request/context persistence.
- `apps/soulbuddy/lib/features/prayers/data/personal_prayer_repository.dart` — accepted-prayer interface.
- `apps/soulbuddy/lib/features/prayers/data/powersync_personal_prayer_repository.dart` — immutable revision/link persistence and watches.
- `apps/soulbuddy/lib/features/prayers/data/prayer_draft_api.dart` — authenticated API contract and safe error types.
- `apps/soulbuddy/lib/features/prayers/data/laravel_prayer_draft_api.dart` — HTTP request/response implementation with no content logging.
- `apps/soulbuddy/lib/features/prayers/application/prayer_generation_dispatcher.dart` — state transitions, retry lease, and response acknowledgement.
- `apps/soulbuddy/lib/features/prayers/providers/personal_prayer_providers.dart` — repository, API, dispatcher, request, and personal-prayer providers.
- `apps/soulbuddy/lib/features/prayers/presentation/personalized_prayer_screen.dart` — responsive guided flow shell.
- `apps/soulbuddy/lib/features/prayers/presentation/personalized_prayer_choices.dart` — reusable accessible single-choice controls.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_context_picker.dart` — explicit Encounter/Scripture selection.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_draft_screen.dart` — editable generated result and acceptance actions.
- `apps/soulbuddy/lib/features/prayers/presentation/personal_prayer_detail_screen.dart` — accepted prayer view and Today action.
- `apps/soulbuddy/test/features/prayers/prayer_generation_repository_test.dart`
- `apps/soulbuddy/test/features/prayers/personal_prayer_repository_test.dart`
- `apps/soulbuddy/test/features/prayers/personalized_prayer_flow_test.dart`
- `apps/soulbuddy/test/features/prayers/prayer_generation_dispatcher_test.dart`
- `apps/soulbuddy/integration_test/personalized_prayer_flow_test.dart`

### Flutter files to modify

- `apps/soulbuddy/lib/core/database/app_schema.dart` — four new prayer tables and typed Today selection.
- `apps/soulbuddy/lib/core/identity/local_identity_providers.dart` — reusable application-session token reader.
- `apps/soulbuddy/lib/features/prayers/data/prayer_repository.dart` — typed Today selection API.
- `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_repository.dart` — union library and personal prayer content for Today.
- `apps/soulbuddy/lib/features/prayers/domain/today_prayer.dart` — display prayer plus typed source.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_choices.dart` — enable and navigate personalized creation.
- `apps/soulbuddy/lib/features/prayers/presentation/prayer_detail_screen.dart` — pass library reference to Today.
- `apps/soulbuddy/lib/features/prayers/providers/prayer_providers.dart` — typed Today calls without cross-feature retry teardown.
- `apps/soulbuddy/lib/features/scripture/data/scripture_repository.dart` — catalog methods needed by the controlled picker.
- `apps/soulbuddy/lib/features/scripture/data/sqlite_scripture_repository.dart` — books/chapters lookup.
- `apps/soulbuddy/lib/app/router.dart` — create, draft, and personal-prayer routes.
- `apps/soulbuddy/test/helpers/in_memory_prayer_repository.dart` — typed Today test double.
- `apps/soulbuddy/test/features/prayers/prayer_repository_test.dart`
- `apps/soulbuddy/test/features/today/today_prayer_test.dart`
- `apps/soulbuddy/test/app/app_navigation_test.dart`

### Laravel files to create

- `services/api/database/migrations/2026_08_11_000001_create_personal_prayer_tables.php`
- `services/api/app/Models/PersonalPrayer.php`
- `services/api/app/Models/PersonalPrayerRevision.php`
- `services/api/app/Models/PersonalPrayerLink.php`
- `services/api/app/Policies/PersonalPrayerPolicy.php`
- `services/api/app/Domain/PrayerDrafts/PrayerDraftInput.php`
- `services/api/app/Domain/PrayerDrafts/PrayerDraftResult.php`
- `services/api/app/Domain/PrayerDrafts/PrayerDraftProvider.php`
- `services/api/app/Domain/PrayerDrafts/DeepSeekPrayerDraftProvider.php`
- `services/api/app/Domain/PrayerDrafts/PrayerDraftPrompt.php`
- `services/api/app/Domain/PrayerDrafts/PrayerDraftValidator.php`
- `services/api/app/Domain/PrayerDrafts/GeneratePrayerDraft.php`
- `services/api/app/Http/Requests/GeneratePrayerDraftRequest.php`
- `services/api/app/Http/Controllers/Api/PrayerDraftController.php`
- `services/api/app/Http/Controllers/Api/PrayerDraftAttemptController.php`
- `services/api/resources/prompts/prayer_draft_v1.md`
- `services/api/tests/Feature/PrayerDraft/GeneratePrayerDraftTest.php`
- `services/api/tests/Feature/PrayerDraft/DeepSeekPrayerDraftProviderTest.php`
- `services/api/tests/Feature/Sync/PersonalPrayerMutationTest.php`
- `services/api/tests/Fixtures/prayer_draft_cases.php`

### Laravel files to modify

- `services/api/.env.example` — placeholders only; never a real key.
- `services/api/config/services.php` — DeepSeek model, URL, timeout, prompt/disclosure versions.
- `services/api/app/Providers/AppServiceProvider.php` — interface binding and named rate limiters.
- `services/api/app/Domain/Sync/ApplySyncMutation.php` — route personal-prayer operations through a focused private handler and add typed Today validation.
- `services/api/app/Models/TodayPrayer.php` — library and personal relationships.
- `services/api/routes/api.php` — authenticated generation and acknowledgement routes.
- `services/api/tests/Feature/Sync/PrayerMutationTest.php` — migration compatibility and typed Today regression coverage.
- `README.md` — local-only behaviour, rotated-key setup, and optional live smoke command.

## Task 1: Add client domain contracts and local-only generation persistence

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_generation_request.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_generation_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_generation_repository.dart`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_generation_repository_test.dart`

- [ ] **Step 1: Write the failing real-PowerSync repository test**

```dart
test('saves choices and explicit context atomically without upload CRUD', () async {
  final database = await openTestDatabase(databasePath);
  addTearDown(database.close);
  final repository = PowerSyncPrayerGenerationRepository(
    database: database.powersync,
    ownerId: 'owner-1',
    now: () => DateTime.utc(2026, 8, 11, 8),
    uuid: const Uuid(),
  );

  final request = await repository.create(
    style: PrayerStyle.situational,
    reach: PrayerReach.encompassing,
    grounding: PrayerGrounding.generalChristian,
    purpose: PrayerPurpose.family,
    requestText: 'Give us wisdom as we care for our family.',
  );
  await repository.replaceContexts(request.id, const [
    PrayerGenerationContext.encounter(
      sourceId: '0198a400-0000-7000-8000-000000000001',
      displayLabel: 'A conversation I remember',
      excerptSnapshot: 'We chose to speak truthfully and forgive.',
    ),
  ]);

  expect((await repository.watch(request.id).first)?.status,
      PrayerGenerationStatus.editing);
  expect(await database.powersync.getNextCrudTransaction(), isNull);
});
```

- [ ] **Step 2: Run the test and observe RED**

Run:

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_generation_repository_test.dart
```

Expected: compilation fails because the generation domain and repository do not exist.

- [ ] **Step 3: Add explicit enums and immutable values**

```dart
enum PrayerStyle { daily('daily'), situational('situational');
  const PrayerStyle(this.wireValue); final String wireValue;
}
enum PrayerReach { personal('personal'), encompassing('encompassing');
  const PrayerReach(this.wireValue); final String wireValue;
}
enum PrayerGenerationStatus {
  editing('editing'), queued('queued'), generating('generating'),
  ready('ready'), needsAttention('needs_attention');
  const PrayerGenerationStatus(this.wireValue); final String wireValue;
}

class PrayerGenerationContext {
  const PrayerGenerationContext._({
    required this.type, required this.sourceId, required this.displayLabel,
    required this.excerptSnapshot, this.translation, this.book,
    this.chapter, this.firstVerse, this.lastVerse,
  });
  const PrayerGenerationContext.encounter({
    required String sourceId, required String displayLabel,
    required String excerptSnapshot,
  }) : this._(type: 'encounter', sourceId: sourceId,
         displayLabel: displayLabel, excerptSnapshot: excerptSnapshot);
  final String type;
  final String sourceId;
  final String displayLabel;
  final String excerptSnapshot;
  final String? translation;
  final String? book;
  final int? chapter;
  final int? firstVerse;
  final int? lastVerse;
}
```

Add `PrayerGenerationRequest` with every field from the design table, `copyWith`, row parsing that rejects unknown wire values, and a `hasUserEdits` comparison for regeneration confirmation.

- [ ] **Step 4: Add the two local-only schema tables**

```dart
Table.localOnly('prayer_generation_requests', [
  Column.text('owner_id'), Column.text('style'), Column.text('reach'),
  Column.text('grounding'), Column.text('purpose'),
  Column.text('request_text'), Column.text('beneficiary_choice'),
  Column.text('surrender_choice'), Column.text('responsibility_choice'),
  Column.text('alignment_choice'), Column.text('status'),
  Column.text('draft_title'), Column.text('draft_body'),
  Column.text('draft_action'),
  Column.text('generated_title'), Column.text('generated_body'),
  Column.text('generated_action'), Column.text('prompt_version'),
  Column.text('provider_disclosure_version'),
  Column.text('consented_provider'),
  Column.text('consented_disclosure_version'),
  Column.text('active_attempt_id'), Column.text('attempt_started_at'),
  Column.text('next_attempt_at'), Column.integer('attempt_count'),
  Column.text('last_attempt_at'), Column.text('failure_code'),
  Column.text('accepted_prayer_id'),
  Column.text('created_at'), Column.text('updated_at'),
], indexes: [
  Index('prayer_generation_owner_status', [
    IndexedColumn('owner_id'), IndexedColumn('status'),
  ]),
]),
Table.localOnly('prayer_generation_contexts', [
  Column.text('request_id'), Column.text('context_type'),
  Column.text('source_id'), Column.text('display_label'),
  Column.text('excerpt_snapshot'), Column.text('translation'),
  Column.text('book'), Column.integer('chapter'),
  Column.integer('first_verse'), Column.integer('last_verse'),
  Column.text('created_at'),
], indexes: [
  Index('prayer_generation_context_parent', [IndexedColumn('request_id')]),
]),
```

- [ ] **Step 5: Implement transactional persistence and queue leases**

The repository interface must expose exactly:

```dart
abstract interface class PrayerGenerationRepository {
  Stream<PrayerGenerationRequest?> watch(String id);
  Stream<List<PrayerGenerationRequest>> watchPending();
  Future<PrayerGenerationRequest> create({
    required PrayerStyle style, required PrayerReach reach,
    required PrayerGrounding grounding, required PrayerPurpose purpose,
    required String requestText,
  });
  Future<void> update(PrayerGenerationRequest request);
  Future<void> replaceContexts(String requestId,
      List<PrayerGenerationContext> contexts);
  Future<void> queue(String requestId, {
    required String provider, required String disclosureVersion,
  });
  Future<bool> claim(String requestId, String attemptId, DateTime now);
  Future<void> storeDraft(String requestId, String attemptId,
      PrayerGeneratedDraft draft);
  Future<void> defer(String requestId, String attemptId, {
    required DateTime nextAttemptAt, String? failureCode,
  });
  Future<void> requireAttention(String requestId, String attemptId,
      String failureCode);
}
```

Use one `writeTransaction` for request/context replacement, owner-scope every update, trim user text, cap the request at 500 characters, and implement `claim` as a conditional update that also reclaims leases older than 20 seconds.

- [ ] **Step 6: Run focused GREEN and the full Flutter suite**

```powershell
cd apps/soulbuddy
dart format lib test
flutter test test/features/prayers/prayer_generation_repository_test.dart
flutter analyze
flutter test
```

Expected: the focused test passes, analysis reports no issues, and the existing suite remains green.

- [ ] **Step 7: Commit Task 1**

```powershell
git add apps/soulbuddy/lib/core/database/app_schema.dart apps/soulbuddy/lib/features/prayers/domain/prayer_generation_request.dart apps/soulbuddy/lib/features/prayers/data/prayer_generation_repository.dart apps/soulbuddy/lib/features/prayers/data/powersync_prayer_generation_repository.dart apps/soulbuddy/test/features/prayers/prayer_generation_repository_test.dart
git commit -m "feat: persist personalized prayer requests"
```

## Task 2: Persist accepted personal prayers and typed Today selections end to end

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/domain/personal_prayer.dart`
- Create: `apps/soulbuddy/lib/features/prayers/domain/prayer_reference.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/personal_prayer_repository.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/powersync_personal_prayer_repository.dart`
- Create: `services/api/database/migrations/2026_08_11_000001_create_personal_prayer_tables.php`
- Create: `services/api/app/Models/PersonalPrayer.php`
- Create: `services/api/app/Models/PersonalPrayerRevision.php`
- Create: `services/api/app/Models/PersonalPrayerLink.php`
- Create: `services/api/app/Policies/PersonalPrayerPolicy.php`
- Test: `apps/soulbuddy/test/features/prayers/personal_prayer_repository_test.dart`
- Test: `services/api/tests/Feature/Sync/PersonalPrayerMutationTest.php`
- Modify: `apps/soulbuddy/lib/core/database/app_schema.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/prayer_repository.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/data/powersync_prayer_repository.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/domain/today_prayer.dart`
- Modify: `services/api/app/Domain/Sync/ApplySyncMutation.php`
- Modify: `services/api/app/Models/TodayPrayer.php`

- [ ] **Step 1: Write RED Flutter tests for atomic acceptance and typed Today**

```dart
test('accepts one draft as prayer revision and explicit links atomically', () async {
  final accepted = await repository.accept(
    requestId: request.id,
    title: 'For wisdom in my family',
    body: 'Father, give us wisdom and make us ready to act in love. Amen.',
    action: 'Call and listen without defending myself.',
  );
  expect(accepted.currentRevisionId, isNotEmpty);
  expect(await database.powersync.getAll('SELECT * FROM personal_prayers'),
      hasLength(1));
  expect(await database.powersync.getAll('SELECT * FROM personal_prayer_revisions'),
      hasLength(1));
  expect(await database.powersync.getAll('SELECT * FROM personal_prayer_links'),
      hasLength(1));
});

test('Today reads a personal current revision without library voting', () async {
  await todayRepository.selectForToday(
    const PrayerReference.personal('personal-1'), includeAction: true);
  final today = await todayRepository.watchToday(DateTime(2026, 8, 11)).first;
  expect(today?.prayer.reference,
      const PrayerReference.personal('personal-1'));
  expect(today?.prayer.title, 'My accepted prayer');
});
```

- [ ] **Step 2: Write RED Laravel migration and mutation tests**

The Pest tests must assert:

```php
expect(Schema::hasColumns('personal_prayers', [
    'id', 'user_id', 'title', 'style', 'reach', 'grounding',
    'purpose', 'current_revision_id', 'archived_at',
]))->toBeTrue();
expect(Schema::hasColumn('today_prayers', 'personal_prayer_id'))->toBeTrue();

$this->actingAs($user)->postJson('/api/sync/mutations', [
    'operations' => personalPrayerPutWithRevisionAndLink($user),
])->assertOk()->assertJsonPath('accepted', 3);

expect(PersonalPrayer::count())->toBe(1)
    ->and(PersonalPrayerRevision::count())->toBe(1)
    ->and(PersonalPrayerLink::count())->toBe(1);
```

Add cases for missing revision pairs, immutable revision PATCH/DELETE, foreign Encounter links, malformed Scripture links, two-install aliases, replay conflicts, rollback, and personal Today selection owned by another user.

- [ ] **Step 3: Run both focused suites to verify RED**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/personal_prayer_repository_test.dart
cd ..\..\services\api
php artisan test tests/Feature/Sync/PersonalPrayerMutationTest.php
```

Expected: Flutter compilation and Laravel schema assertions fail for the missing slice.

- [ ] **Step 4: Add client tables and exact-one Today columns**

Add `personal_prayers`, `personal_prayer_revisions`, and `personal_prayer_links` as synchronized PowerSync tables. Change Today to contain nullable `prayer_id` and nullable `personal_prayer_id`. Define:

```dart
enum PrayerSource { library, personal }

class PrayerReference {
  const PrayerReference.library(this.id) : source = PrayerSource.library;
  const PrayerReference.personal(this.id) : source = PrayerSource.personal;
  final PrayerSource source;
  final String id;
}

class PrayerDisplay {
  const PrayerDisplay({required this.reference, required this.title,
    required this.body, required this.grounding, required this.purpose,
    this.action});
  final PrayerReference reference;
  final String title;
  final String body;
  final PrayerGrounding grounding;
  final PrayerPurpose purpose;
  final String? action;
}
```

Change `TodayPrayer.prayer` from `LibraryPrayer` to `PrayerDisplay`. Change repository selection/completion signatures to accept `PrayerReference expectedPrayer` and use both source and ID in conditional SQL.

- [ ] **Step 5: Implement atomic client acceptance**

`PersonalPrayerRepository.accept` must generate prayer/revision/link UUIDv7 IDs, verify the generation request is `ready`, and write all accepted rows plus the generation request's final status in one PowerSync transaction. An Encounter link copies only its ID; a Scripture link copies structured reference fields and never synchronizes the excerpt snapshot.

- [ ] **Step 6: Add the Laravel migration with referential checks**

The migration must create personal prayer tables before altering Today:

```php
Schema::create('personal_prayers', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('title', 120);
    $table->enum('style', ['daily', 'situational']);
    $table->enum('reach', ['personal', 'encompassing']);
    $table->enum('grounding', ['general_christian', 'catholic']);
    $table->string('purpose', 40);
    $table->uuid('current_revision_id');
    $table->timestamps();
    $table->timestamp('archived_at')->nullable();
    $table->index(['user_id', 'archived_at']);
});
```

Create the revision table with a unique `(id, prayer_id, user_id)` identity and add the current-revision foreign key after both tables exist. Create link constraints for exactly one Encounter or Scripture target. Alter Today so library `prayer_id` is nullable, add nullable `personal_prayer_id`, and add a driver-appropriate exact-one check. The `down()` method must restore the original non-null library-only Today shape only after rejecting a rollback when personal Today rows exist; tests must exercise both safe rollback and guarded refusal.

- [ ] **Step 7: Add a focused personal-prayer mutation handler**

Do not continue growing the 756-line orchestration class. Extract the new rules into:

```php
final class ApplyPersonalPrayerMutation
{
    /** @return null|string safe rejection code */
    public function apply(User $user, Collection $operations): ?string
    {
        // Validate complete prayer/revision pairs first, then lock the user,
        // sorted prayer IDs, sorted revision IDs, and linked encounters.
    }
}
```

`ApplySyncMutation` remains responsible for stored-operation replay and the outer transaction, but delegates the new table subset. Preserve target → pair → data validation precedence and user-first/sorted-record lock order. Store client IDs as aliases when a semantic row from another installation already exists.

- [ ] **Step 8: Extend Today validation for exactly one owned source**

For `today_prayers` PUT/PATCH, accept `prayer_id` or `personal_prayer_id`, never both. Library IDs must be published and unarchived. Personal IDs must belong to the authenticated user and be unarchived. Lock both source sets in lexical order after locking the user. DELETE remains allowed for cleanup even if the selected source has since been archived.

- [ ] **Step 9: Run focused and full GREEN checks**

```powershell
cd apps/soulbuddy
dart format lib test
flutter test test/features/prayers/personal_prayer_repository_test.dart test/features/prayers/prayer_repository_test.dart test/features/today/today_prayer_test.dart
flutter analyze
flutter test
cd ..\..\services\api
vendor\bin\pint --test
php artisan test tests/Feature/Sync/PersonalPrayerMutationTest.php tests/Feature/Sync/PrayerMutationTest.php tests/Feature/Sync/EncounterMutationTest.php
php artisan test
```

Expected: all focused and full suites pass; Pint reports clean.

- [ ] **Step 10: Commit Task 2**

```powershell
git add apps/soulbuddy services/api
git commit -m "feat: sync accepted personal prayers"
```

## Task 3: Build the controlled guided flow and explicit context pickers

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/presentation/personalized_prayer_screen.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/personalized_prayer_choices.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_context_picker.dart`
- Create: `apps/soulbuddy/lib/features/prayers/providers/personal_prayer_providers.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/presentation/prayer_library_choices.dart`
- Modify: `apps/soulbuddy/lib/features/scripture/data/scripture_repository.dart`
- Modify: `apps/soulbuddy/lib/features/scripture/data/sqlite_scripture_repository.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/prayers/personalized_prayer_flow_test.dart`
- Test: `apps/soulbuddy/test/app/app_navigation_test.dart`

- [ ] **Step 1: Write RED widget tests for both dynamic paths**

```dart
testWidgets('daily path skips Before you ask and saves every choice', (tester) async {
  await tester.pumpWidget(testApp());
  await tester.tap(find.text('Create personalized'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Daily / affirming'));
  await tester.tap(find.text('Personal'));
  await tester.tap(find.text('General Christian'));
  await tester.tap(find.text('Guidance'));
  await tester.enterText(find.byKey(const Key('prayer-request-field')),
      'Help me receive and use wisdom today.');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('Before you ask'), findsNothing);
  expect(find.text('Add context'), findsOneWidget);
});

testWidgets('situational path offers choices instead of open questions',
    (tester) async {
  await reachBeforeYouAsk(tester);
  expect(find.text('Who should this blessing help?'), findsOneWidget);
  expect(find.text('People affected by this'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
});
```

Add 200% text-scale, keyboard traversal, semantics-selected, back-navigation persistence, and filter-preservation cases.

- [ ] **Step 2: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/personalized_prayer_flow_test.dart test/app/app_navigation_test.dart
```

Expected: route and widgets are missing.

- [ ] **Step 3: Add a repository-backed controller with one state owner**

Use an auto-disposed Riverpod controller whose only mutable UI field is the current step; all user choices are immediately persisted through `PrayerGenerationRepository.update`. On re-entry, load the request by route ID. Never keep the only copy of entered text in a `TextEditingController`.

```dart
final personalizedPrayerControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PersonalizedPrayerController, PrayerGenerationRequest, String>(
  PersonalizedPrayerController.new,
);
```

- [ ] **Step 4: Implement the option-led responsive UI**

Create a maximum-width 720 layout using the existing spacing/type tokens. `PersonalizedPrayerChoices` renders one semantic radio group with 48px minimum targets. The step sequence is style → reach → grounding → purpose → request → conditional examination → context → consent. Situational prayers show all four approved `Before you ask` choice groups; daily prayers skip them.

- [ ] **Step 5: Add a controlled Scripture catalog**

Extend the repository without exposing raw database tables:

```dart
abstract interface class ScriptureRepository {
  Future<List<String>> books();
  Future<List<int>> chapters(String book);
  Future<ScripturePassage> chapter({required String book,
    required int chapter});
  Future<ScripturePassage> verses({required String book,
    required int chapter, required int firstVerse,
    required int lastVerse});
}
```

The picker uses dropdown/list choices for book and chapter, then selectable verse rows. It snapshots at most 20 consecutive verses and labels the source `RSVCE · Scripture`. Encounter selection watches `encountersProvider`, shows title/date only until chosen, and snapshots at most 2,000 characters after explicit selection.

- [ ] **Step 6: Wire routes and enable the existing choice**

Add routes:

```dart
GoRoute(path: 'create', builder: (_, __) => const PersonalizedPrayerScreen()),
GoRoute(path: 'requests/:requestId', builder: (_, state) =>
  PersonalizedPrayerScreen(requestId: state.pathParameters['requestId'])),
```

Change `PrayerLibraryChoices` to accept `onLibrary` and `onPersonalized` callbacks, remove the lock icon and `Next` copy, and navigate to `/prayers/create` without resetting the library branch.

- [ ] **Step 7: Run focused and full Flutter GREEN**

```powershell
cd apps/soulbuddy
dart format lib test
flutter test test/features/prayers/personalized_prayer_flow_test.dart test/app/app_navigation_test.dart test/features/scripture/sqlite_scripture_repository_test.dart
flutter analyze
flutter test
```

- [ ] **Step 8: Commit Task 3**

```powershell
git add apps/soulbuddy
git commit -m "feat: add guided prayer choices"
```

## Task 4: Add the authenticated DeepSeek draft service and safety contract

**Files:**
- Create all `services/api/app/Domain/PrayerDrafts/*` files listed above
- Create: `services/api/app/Http/Requests/GeneratePrayerDraftRequest.php`
- Create: `services/api/app/Http/Controllers/Api/PrayerDraftController.php`
- Create: `services/api/app/Http/Controllers/Api/PrayerDraftAttemptController.php`
- Create: `services/api/resources/prompts/prayer_draft_v1.md`
- Create: `services/api/tests/Feature/PrayerDraft/GeneratePrayerDraftTest.php`
- Create: `services/api/tests/Feature/PrayerDraft/DeepSeekPrayerDraftProviderTest.php`
- Modify: `services/api/config/services.php`
- Modify: `services/api/app/Providers/AppServiceProvider.php`
- Modify: `services/api/routes/api.php`
- Modify: `services/api/.env.example`

- [ ] **Step 1: Write RED endpoint tests before provider code**

Cover unauthenticated 401; current disclosure/prompt versions; unknown keys; invalid enums; request/context size; no consent; rate limit; encrypted idempotent replay; one repair; second invalid result; provider 429/timeout/5xx; and log redaction.

```php
it('returns one validated draft without logging private content', function () {
    $user = User::factory()->create();
    $private = 'Help my family through this private decision.';
    Log::spy();
    $this->mock(PrayerDraftProvider::class)
        ->shouldReceive('generate')->once()
        ->andReturn(new PrayerDraftResult(
            'For wisdom',
            'Father, give us wisdom, truth, patience, and love as we decide. Amen.',
            'Listen before offering an answer.',
        ));

    $this->actingAs($user)->postJson('/api/prayer-drafts',
        validPrayerDraftPayload(requestText: $private))
        ->assertOk()->assertJsonPath('draft.title', 'For wisdom');

    foreach (['error', 'warning', 'info', 'debug', 'log'] as $level) {
        Log::shouldNotHaveReceived($level);
    }
});
```

- [ ] **Step 2: Run RED**

```powershell
cd services/api
php artisan test tests/Feature/PrayerDraft
```

Expected: missing routes/classes.

- [ ] **Step 3: Add strict request validation and DTOs**

`GeneratePrayerDraftRequest` must reject unknown top-level, choice, and context keys before applying Laravel rules. Permit zero to two contexts, no more than one per type, request text 1–500 characters, Encounter excerpt 1–2,000, and Scripture excerpt 1–4,000. Do not accept owner/user IDs.

`PrayerDraftInput` contains typed PHP enums or validated strings plus explicit context values. `PrayerDraftResult` contains only title, body, and nullable action.

- [ ] **Step 4: Write the versioned prompt exactly once**

The prompt file must contain the complete approved content contract and this output instruction:

```text
Return one JSON object with exactly these keys:
{"title":"...","body":"...","action":null}

The body is a direct prayer addressed to God, 60–140 words.
Do not claim that God spoke, promised, caused an event, diagnosed the person,
or guaranteed an outcome. Do not invent or quote Scripture. Any supplied
Scripture excerpt is context only and is displayed separately by SoulBuddy.
Catholic grounding does not require a formal prayer format, saintly
intercession, or doctrine not requested by the person. General Christian
grounding must not argue against Catholic belief or impose a denomination.
The optional action is 3–18 words and is never presented as God's command.
```

Append structured choices and context using `json_encode(..., JSON_THROW_ON_ERROR)` so user content cannot become prompt instructions. Give user/context JSON a clearly delimited data role.

- [ ] **Step 5: Implement the DeepSeek adapter with JSON output**

```php
$response = Http::baseUrl(config('services.deepseek.base_url'))
    ->withToken(config('services.deepseek.key'))
    ->acceptJson()->asJson()->timeout(20)
    ->post('/chat/completions', [
        'model' => config('services.deepseek.model'),
        'thinking' => ['type' => 'disabled'],
        'messages' => $messages,
        'response_format' => ['type' => 'json_object'],
        'max_tokens' => 350,
        'temperature' => 0.3,
        'user_id' => hash('sha256', 'soulbuddy:'.$user->public_id),
    ]);
```

Map 429 to `PrayerDraftRateLimited`, timeouts/5xx to `PrayerDraftUnavailable`, malformed envelopes to `PrayerDraftInvalidResponse`, and never include response bodies in exception messages.

- [ ] **Step 6: Validate and repair once**

`PrayerDraftValidator` enforces exact keys, UTF-8 strings, title 1–120 characters, body 60–140 Unicode words, action null or 3–18 words, no control characters, and case-insensitive prohibited phrases. It rejects Bible-reference patterns when no selected reference was supplied and any quotation-shaped excerpt copied from unselected text.

`GeneratePrayerDraft` calls the provider once, validates, then calls it one final time with only the safe validation codes and original structured input. It never returns either invalid result.

- [ ] **Step 7: Add encrypted ten-minute idempotency and acknowledgement**

Cache key: `prayer-draft:{userPublicId}:{attemptId}`. Use an atomic cache lock for concurrent calls and `Crypt::encryptString(json_encode($draft))` for the cached value. The DELETE acknowledgement verifies the authenticated cache namespace and forgets only that attempt. No prayer text enters cache keys.

- [ ] **Step 8: Bind, rate-limit, route, and configure without secrets**

`.env.example` contains only:

```dotenv
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-flash
PRAYER_DRAFT_PROMPT_VERSION=1
PRAYER_DRAFT_DISCLOSURE_VERSION=deepseek-1
```

Bind `PrayerDraftProvider` to `DeepSeekPrayerDraftProvider`. Define limits of 10/user/hour, 30/user/day, and 30/IP/hour. Put both routes inside the existing `auth:sanctum` group.

- [ ] **Step 9: Add and run the non-private evaluation fixture**

`prayer_draft_cases.php` returns at least 32 synthetic cases covering both styles/reaches/groundings, all purposes, every examination choice, selected/unselected contexts, status, money, healing, conflict, forgiveness, work, family, and disappointment. Tests feed deterministic fake outputs through the validator; no live provider is used in CI.

```powershell
vendor\bin\pint
php artisan test tests/Feature/PrayerDraft
php artisan test
composer validate --strict
composer audit --locked
```

Expected: all tests pass, Composer is valid, and audit reports no advisories.

- [ ] **Step 10: Commit Task 4**

```powershell
git add services/api
git commit -m "feat: generate guarded prayer drafts"
```

## Task 5: Dispatch queued requests and accept editable drafts in Flutter

**Files:**
- Create: `apps/soulbuddy/lib/features/prayers/data/prayer_draft_api.dart`
- Create: `apps/soulbuddy/lib/features/prayers/data/laravel_prayer_draft_api.dart`
- Create: `apps/soulbuddy/lib/features/prayers/application/prayer_generation_dispatcher.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/prayer_draft_screen.dart`
- Create: `apps/soulbuddy/lib/features/prayers/presentation/personal_prayer_detail_screen.dart`
- Modify: `apps/soulbuddy/lib/core/identity/local_identity_providers.dart`
- Modify: `apps/soulbuddy/lib/features/prayers/providers/personal_prayer_providers.dart`
- Modify: `apps/soulbuddy/lib/app/router.dart`
- Test: `apps/soulbuddy/test/features/prayers/prayer_generation_dispatcher_test.dart`
- Test: `apps/soulbuddy/test/features/prayers/personalized_prayer_flow_test.dart`

- [ ] **Step 1: Write RED dispatcher state-machine tests**

Test success, offline deferral, missing session, 401, 422, 429 with Retry-After, 5xx, timeout, stale lease recovery, app resume, duplicate dispatch, response acknowledgement after local commit, and acknowledgement failure after local commit.

```dart
test('stores the draft before acknowledging the server attempt', () async {
  final calls = <String>[];
  final api = FakePrayerDraftApi(
    onGenerate: (_) async { calls.add('generate'); return generated; },
    onAcknowledge: (_) async { calls.add('ack'); },
  );
  final dispatcher = PrayerGenerationDispatcher(
    repository: repository, api: api, now: clock, uuid: const Uuid());

  await dispatcher.dispatch(request.id);

  expect(calls, ['generate', 'ack']);
  expect((await repository.watch(request.id).first)?.status,
      PrayerGenerationStatus.ready);
});
```

- [ ] **Step 2: Write RED draft-screen tests**

Assert visible `Prayer draft`, editable fields, separate Scripture/Encounter labels, optional action removal, save, Use today, regeneration replacement confirmation only after edits, leave/reopen persistence, and generic error copy.

- [ ] **Step 3: Run RED**

```powershell
cd apps/soulbuddy
flutter test test/features/prayers/prayer_generation_dispatcher_test.dart test/features/prayers/personalized_prayer_flow_test.dart
```

- [ ] **Step 4: Add the authenticated API client**

```dart
abstract interface class PrayerDraftApi {
  Future<PrayerGeneratedDraft> generate(PrayerGenerationRequest request,
      List<PrayerGenerationContext> contexts, String attemptId);
  Future<void> acknowledge(String attemptId);
}
```

`LaravelPrayerDraftApi` reads the application-session token immediately before each call, never caches it, uses the configured Laravel base URL, sends only allowed structured fields, and maps status codes to content-free exceptions. It must never call `toString()` on request/context values in logging or errors.

- [ ] **Step 5: Implement the dispatcher with bounded retry**

Attempt immediately on consent and explicit Retry. Retry transient failures at 5 seconds, 30 seconds, 2 minutes, 10 minutes, then require manual retry; cap timer delays and resample on app resume. Missing/expired authentication uses `session_required` and never loops. Invalidation must not dispose a healthy `appDatabaseProvider`.

- [ ] **Step 6: Implement consent and editable draft result**

The consent sheet uses the approved DeepSeek disclosure and stores provider/version only after `Prepare draft`. The draft screen reads from the local database, not an HTTP future. Text fields persist on blur and before navigation. `Prepare another draft` confirms only when current editable values differ from the last generated values.

- [ ] **Step 7: Accept and route personal prayers**

`Save prayer` calls `PersonalPrayerRepository.accept`, then replaces the route with `/prayers/saved/{id}`. `Use today` accepts in the same transaction first, then writes a typed personal Today reference and navigates to `/today`. Disable both controls while pending and bind completion to the displayed request ID.

- [ ] **Step 8: Run focused and full Flutter GREEN**

```powershell
cd apps/soulbuddy
dart format lib test
flutter test test/features/prayers/prayer_generation_dispatcher_test.dart test/features/prayers/personalized_prayer_flow_test.dart
flutter analyze
flutter test
flutter build web --debug
flutter build apk --debug
```

- [ ] **Step 9: Commit Task 5**

```powershell
git add apps/soulbuddy
git commit -m "feat: queue and accept prayer drafts"
```

## Task 6: Prove the complete slice on Chrome, Android, and Laravel

**Files:**
- Create: `apps/soulbuddy/integration_test/personalized_prayer_flow_test.dart`
- Modify: `scripts/run_web_integration.ps1`
- Modify: `scripts/verify.ps1`
- Modify: `README.md`
- Test: all Flutter and Laravel suites

- [ ] **Step 1: Write a failing integration target with deterministic private fixtures**

The target must use a dedicated database path and fixed local identity, a fake authenticated Laravel draft endpoint, and explicit close/reopen boundaries. It must prove:

```text
launch → Create personalized → situational choices → Before you ask
→ select Encounter + RSVCE → consent → offline queue → restart
→ authenticated reconnect → draft → edit → save → Use today
→ complete action → close DB/container → reopen → same revision and Today state
```

Assert direct database rows before and after reopen. Never print request, context, draft, or token values on failure; diagnostics report only counts, IDs hashed for the test, route, and safe status codes.

- [ ] **Step 2: Run RED on Chrome**

```powershell
cd apps/soulbuddy
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/personalized_prayer_flow_test.dart -d chrome
```

Expected: the new integration target exposes any missing route/provider/lifecycle boundary.

- [ ] **Step 3: Fix only evidence-backed integration gaps**

Apply the systematic-debugging workflow to each failure. Do not add sleeps or retry loops to hide lifecycle races. Own database/container shutdown explicitly and await every close before reopening the same path.

- [ ] **Step 4: Run the target on the Android emulator**

```powershell
cd apps/soulbuddy
flutter test integration_test/personalized_prayer_flow_test.dart -d emulator-5554
```

Expected: all tests pass on the running API 34 emulator with the native application-support database path.

- [ ] **Step 5: Add the target to both verification scripts**

`run_web_integration.ps1` runs Encounter, prayer-library, and personalized-prayer targets in order and stops on the first non-zero exit. `verify.ps1` keeps analyze, full Flutter tests, web build, Pint, Laravel full tests, Composer validate, and audit.

- [ ] **Step 6: Document safe environment setup**

README instructions say to revoke previously exposed keys, place only a rotated `DEEPSEEK_API_KEY` in ignored `services/api/.env`, seed a development user/session, and never paste a key into a command that appears in logs. The optional live smoke uses one synthetic request, prints only status/latency/token counts, and is not part of CI.

- [ ] **Step 7: Run final verification from clean committed state**

```powershell
.\scripts\verify.ps1
.\scripts\run_web_integration.ps1
cd apps\soulbuddy
flutter test integration_test/personalized_prayer_flow_test.dart -d emulator-5554
flutter build apk --debug
cd ..\..
git diff --check
git status --short
```

Expected: every command exits 0. The only allowed status entry outside committed implementation is the user's pre-existing untracked `spiritual_wealth_app_framework.md`.

- [ ] **Step 8: Commit Task 6**

```powershell
git add apps/soulbuddy/integration_test/personalized_prayer_flow_test.dart scripts/run_web_integration.ps1 scripts/verify.ps1 README.md
git commit -m "test: verify personalized prayer flow"
```

## Plan self-review record

- **Spec coverage:** This plan covers the approved generation flow, explicit Encounter/Scripture context, DeepSeek consent/provider/safety, local queue, accepted immutable prayers, typed Today compatibility, privacy, accessibility, content evaluation, Chrome, and Android. Reminder, narration, sessions, and publication are excluded deliberately because the approved design contains independent subsystems that require their own plans after this vertical slice is stable.
- **Placeholder scan:** No TBD, TODO, generic error-handling step, or deferred code stub remains.
- **Type consistency:** `PrayerReference`, `PrayerDisplay`, `PrayerGenerationRequest`, `PrayerGeneratedDraft`, repository methods, API methods, and route parameters use the same names across tasks.
- **Secret handling:** No credential value appears in this plan. Live verification requires a newly rotated key stored only in ignored Laravel environment configuration.
